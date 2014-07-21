<?php /* Template Name: Maps Live Track */ ?>


<?php get_header(); ?>

    <script src="https://www.google.com/jsapi"></script>
    <script src="https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false"></script>
    <script type="text/javascript">
      var ELEVATION_LIMIT = 50;
      var PREVIOUS_PATH_COLOR = '#013ADF';
      var TODAY_PATH_COLOR = '#FF0000';

      var map;
      var chart;

      // Load the Visualization API and the columnchart package.
      google.load('visualization', '1', {packages: ['columnchart']});

      // Register the initialize function to be executed on load.
      google.maps.event.addDomListener(window, 'load', initialize);
      
      function initialize() {
	  var myLatLng = new google.maps.LatLng(0, -180);
	  var mapOptions = {
	      zoom: 8,
	      center: myLatLng,
	      mapTypeId: google.maps.MapTypeId.TERRAIN
	  };
	  
	  map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions);
	  chart = new google.visualization.ColumnChart(document.getElementById('elevation-canvas'));
	  
	  $(document).ready(function () {
	      $.ajax({
		  type: "GET",
		  url: "http://www.road-adventure.com/spot_archive/maps/last_n_points.csv",
		  contentType: "text/csv",
		  success: function(data) { processData(data); }
	      });
	  });
      }
      
      function processData(allText) {
	  var rawTextLines = allText.split(/\r\n|\n/);
	  
	  // Get the timestamp of last night at midnight last night (this morning) 
	  // at the current client side's timezone.
	  var d = new Date();
	  d.setHours(0,0,0,0);
	  var midnightEpoch = d.getTime() / 1000;
	  
	  var currentLocation = new google.maps.LatLng(0.0, 0.0);
	  var pathElevation = [];
	  var pathPrevious = [];  
	  var pathToday = [];
	  var timestampsPrevious = [];
	  var timestampsToday = [];

	  // Assumption: the data is sorted in recency.  This means that when this 
	  // loop is finished the most recent location is saved in currentLocation.
	  for (var i = 0; i < rawTextLines.length - 1; i++) {
	      // Each entry is formatted: (lat,lon,epochtimestamp)
	      var entries = rawTextLines[i].split(',');
	      currentLocation = new google.maps.LatLng(entries[0], entries[1]);
	      var timestamp = entries[2];

	      // Group coordinates based on today vs any other day.
	      if (midnightEpoch > entries[2]) {
		  pathPrevious.push(currentLocation);
		  timestampsPrevious.push(timestamp);
	      } else {
		  pathToday.push(currentLocation);
		  timestampsToday.push(timestamp);
	      }
	      
	      // Save the most recen ELEVATION_LIMIT points to later use for the elevation plot.
	      if (ELEVATION_LIMIT > rawTextLines.length - i) {
		  pathElevation.push(currentLocation);
	      }
	  }

	  // Calculate travel statistics.
	  var travelStatisticsHTML = buildTravelStatistics(pathToday, timestampsToday, timestampsPrevious);

	  // We have to link the last point of the pathPrevious to pathToday since
	  // the paths are actually connected yet the code above splits them in two
	  // separate sets of points which causes a gap when you draw the paths.
	  // To avoid this gap I will add the last point from pathPrevious to pathToday.
	  if (pathPrevious.length > 0) {
	      pathToday.unshift(pathPrevious[pathPrevious.length - 1]); 
	  }

	  // Draw all elements on the map.
	  drawPath(pathPrevious, PREVIOUS_PATH_COLOR);
	  drawPath(pathToday, TODAY_PATH_COLOR);
	  drawCurrentLocation(currentLocation);
	  drawMapLegend(travelStatisticsHTML);
	  drawElevationPlot(pathElevation);
      }

      function buildTravelStatistics(path, tToday, tPrevious) {
	  var html = "";

	  // Nothing to display if no timestamps (means no coordinates period)
	  if (tPrevious.length === 0 && tToday.length === 0) {
	      html = "No data reported.";
	      
	  } else if (tToday.length > 1) {
	      // We have at least two points.  Calculate speed, time and distance in km/h.
	      var distance = calculateDistance(path);
	      var time = (tToday[tToday.length - 1] - tToday[0]) / 3600;
	      var speed = distance / time;
	      var lastUpdated = getLastUpdatedStr(tToday[tToday.length - 1]);

	      // Generate HTML display the data.
	      html = "Our drive today <img src=\"http://www.road-adventure.com/spot_archive/maps/redDash.png\" valign=middle><br>" + 
		  "Distance:     " + distance.toFixed(0) + "km<br>" +
		  "Avg Speed:    " + speed.toFixed(0) + "km/h<br>" +
		  "Time driving: " + time.toFixed(0) + "hours<br>" + 
		  "Last update:  " + lastUpdated + "<br>";

	  } else if (tToday.length == 1) {
	      var lastUpdated = getLastUpdatedStr(tToday[0]);
	      html = "We are on the move <img src=\"http://www.road-adventure.com/spot_archive/maps/redDash.png\" valign=middle><br>" +
		  "Last update:  " + lastUpdated + "<br>";
	  } else {
	      var lastDate = new Date(tPrevious[tPrevious.length - 1] * 1000);
	      html = "At this location since<br> " +  lastDate.toLocaleString();
	  }

	  html = "<div style=\"margin: 5px\">" + html + "</div>";
	  return html;
      }

      function getLastUpdatedStr(t) {
	  var lastUpdateS = ((new Date()).getTime() / 1000) - t;
	  var lastUpdateM = Math.ceil((lastUpdateS / 60) % 60);
	  var lastUpdateH = Math.floor(lastUpdateS / 3600);
	  
	  if (lastUpdateH === 0) {
	      return lastUpdateM + "minutes ago";
	  }
	  return lastUpdateH + "h " + lastUpdateM + "m ago";
      }

      function calculateDistance(path) {
	  var distance = 0.0;
	  for (var i = 1; i < path.length; i++) {
	      var from = path[i - 1];
	      var to = path[i];
	      distance += calculateDistanceTwoPointsKM(from.lat(), from.lng(), to.lat(), to.lng());
	  }
	  return distance;
      }

      // Code in this function taken from:
      // http://www.movable-type.co.uk/scripts/latlong.html
      function calculateDistanceTwoPointsKM(lat1,lon1,lat2,lon2) {
	  var R = 6371; // km
	  var dLat = (lat2-lat1).toRad();
	  var dLon = (lon2-lon1).toRad(); 
	  var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
	      Math.cos(lat1.toRad()) * Math.cos(lat2.toRad()) * 
	      Math.sin(dLon/2) * Math.sin(dLon/2); 
	  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
	  return R * c;
      }

      // ---- extend Number object with methods for converting degrees/radians

      /** Converts numeric degrees to radians */
      if (typeof Number.prototype.toRad == 'undefined') {
	  Number.prototype.toRad = function() {
	      return this * Math.PI / 180;
	  }
      }

      // ---- end extend Number object with methods for converting degrees/radians

      /**
       * Comment
       * @param {Number} b
       * @return {Number} sum
       */
      function drawCurrentLocation(currentLocation) {
	  // Center the map around our current position.
	  map.setCenter(currentLocation);
	  
	  // Draw the a marker for our current position.
	  var image = 'http://www.road-adventure.com/spot_archive/maps/taco.png';
	  var tacoMarker = new google.maps.Marker({
	      position: currentLocation,
	      map: map,
	      icon: image
	  });
      }

      function drawPath(path, color) {
	  if (path.length > 1) {
	      var drivePath = new google.maps.Polyline({
		  path: path,
		  strokeColor: color,
		  strokeOpacity: 0.8,
		  strokeWeight: 2,
		  clickable: true
	      });
	      drivePath.setMap(map);
	  }
      }

      function drawMapLegend(html) {
	  var mapLegend = document.getElementById('map-legend');
	  mapLegend.innerHTML = html; 
	  map.controls[google.maps.ControlPosition.RIGHT_TOP].push(mapLegend);
      }

      function drawElevationPlot(path) {
	  var pathRequest = {
	      'path': path,
	      'samples': 512
	  }

	  elevator = new google.maps.ElevationService();
	  elevator.getElevationAlongPath(pathRequest, plotElevation);
      }

      // Takes an array of ElevationResult objects, draws the path on the map
      // and plots the elevation profile on a Visualization API ColumnChart.
      function plotElevation(results, status) {
	  if (status != google.maps.ElevationStatus.OK) {
	      return;
	  }
	  var elevations = results;

	  // Extract the elevation samples from the returned results
	  // and store them in an array of LatLngs so we canculate distance.
	  var elevationPath = [];
	  for (var i = 0; i < results.length; i++) {
	      elevationPath.push(elevations[i].location);
	  }
	  var distance = Math.ceil(calculateDistance(elevationPath));
	  
	  // Extract the data from which to populate the chart.
	  var data = new google.visualization.DataTable();
	  data.addColumn('string', 'Kilometer');
	  data.addColumn('number', 'Elevation');
	  for (var i = 0; i < results.length; i++) {
	      data.addRow(['', elevations[i].elevation]);
	  }
	  
	  // Draw the chart using the data within its DIV.
	  document.getElementById('elevation-canvas').style.display = 'block';
	  var chartOptions = {
	      height: 300,
	      legend: 'none',
	      colors: ['#FF0000'],
	      titleY: 'Elevation (meters)',
	      title: 'Elevation plot for our most recent ' + distance + 'km'
	  }
	  chart.draw(data, chartOptions);
      }
    </script>
    
    <div id="primary">
        <div id="map-canvas" style="height:600px; width:1000px;"></div>
	<div id="map-legend" style="background: white; border: 1px solid gray; margin: 0px 5px; width: 150px; hight: 50px"></div>
	<div id="elevation-canvas" style="height:300px; width:1000px;"></div>
    </div>

<?php get_footer(); ?>
