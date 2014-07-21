<?php /* Template Name: Maps Full Path */ ?>


<?php get_header(); ?>
    <script src="https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false&libraries=visualization"></script>
    <script src="http://code.jquery.com/jquery-1.8.2.min.js"></script>
    <script type="text/javascript">
      // We will need the map as a global variable since we have to add elements to it
      // after we have loaded all the date in ajax.  
      var map;
      var drivePath;
      var heatmap;
      
      // Register the initialize function to be executed on load.
      google.maps.event.addDomListener(window, 'load', initialize);
      
      function initialize() {
	  var myLatLng = new google.maps.LatLng(0, -180);
	  var mapOptions = {
	      zoom: 2,
	      center: myLatLng,
	      mapTypeId: google.maps.MapTypeId.TERRAIN
	  };
	  
	  map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions);
	  
	  $(document).ready(function () {
	      $.ajax({
		  type: "GET",
		  url: "http://www.road-adventure.com/spot_archive/maps/full_trip_coordinates.csv",
		  contentType: "text/csv",
		  success: function(data) { processData(data); }
	      });
	  });
      }
      
      function processData(allText) {
	  var rawTextLines = allText.split(/\r\n|\n/);
	  
	  // Parse the raw text lines and create LatLng data points. 
	  var pathCoordinates = [];
	  for (var i = 0; i < rawTextLines.length - 1; i++) {
	      var entries = rawTextLines[i].split(',');
	      pathCoordinates.push(new google.maps.LatLng(entries[0], entries[1]));
	  }
	  
	  // Draw the drive path.
	  drivePath = new google.maps.Polyline({
	      path: pathCoordinates,
	      strokeColor: '#013ADF',
	      strokeOpacity: 1.0,	     
	      strokeWeight: 2,
	      clickable: true
	  });
	  // drivePath.setPath(pathCoordinates);
	  drivePath.setMap(map);
	  
	  // Our current location is the last point in the pathCoordinates array.
	  var currentLocation = pathCoordinates[pathCoordinates.length - 1];
	  
	  // Center the map around our current position.
	  map.setCenter(currentLocation);
	  
	  // Draw the a marker for our current position.
	  var image = 'http://www.road-adventure.com/spot_archive/maps/taco.png';
	  var tacoMarker = new google.maps.Marker({
	      position: currentLocation,
	      map: map,
	      icon: image
	  });

	  // Draw heatmap.
	  heatmap = new google.maps.visualization.HeatmapLayer({
	      data: pathCoordinates
	  });
	  heatmap.setMap(map);
      }

      function toggleHeatmap() {
	  heatmap.setOptions({opacity: heatmap.get('opacity') ? null : 0.01});
      }

      function togglePath() {
	  if (drivePath.getVisible()) {
	      drivePath.setVisible(false);
	  } else {
	      drivePath.setVisible(true);
	  }
      }
    </script>
    
    <div id="primary">
      <div id="panel" valign="bottom">
	<button onclick="toggleHeatmap()">Toggle Heatmap</button>
	<button onclick="togglePath()">Toggle Path</button>
      </div>
      <div id="map-canvas" style="height:600px; width:1000px;"></div>
    </div><!-- #primary -->
<?php get_footer(); ?>
