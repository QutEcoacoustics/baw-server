$(document).ready(function () {
    $('body').tooltip({selector: "[data-toggle~='tooltip']"})
});


// for site location map

// expects two global variables:
// var markersArray = [];
var setLocationMarker = null;

function createMarker(map, latLng, text, isInfoWindowOpen, draggable) {
    var instructions = 'Drag marker to site location. Delete Latitude and Longitude to specify no location.';

    // calculate defaults
    var draggableValue = (typeof draggable !== 'undefined' || !draggable) ? draggable : false;
    var isInfoWindowOpenValue = (typeof isInfoWindowOpen !== 'undefined' || !isInfoWindowOpen) ? isInfoWindowOpen : true;
    var textValue = text ? text : instructions;

    // create a new marker
    var marker = new google.maps.Marker({
        position: latLng,
        map: map,
        draggable: draggableValue,
        title: textValue
    });

    createInfoWindow(map, marker, textValue, isInfoWindowOpenValue);

    if (draggable) {
        // when the marker stops being dragged, update the lat and lng fields
        marker.addListener('dragend', function () {
            setFieldLatLng(marker.getPosition());
        });
    }

    return marker;
}

function createInfoWindow(map, marker, text, isInfoWindowOpen) {
    var infowindow = new google.maps.InfoWindow({content: text});
    marker.addListener('click', function () {
        infowindow.open(map, marker);
    });
    if (isInfoWindowOpen) {
        infowindow.open(map, marker);
    }
    return infowindow;
}

function zoomToBounds(map, bounds, zoom) {
    map.fitBounds(bounds);
    if (zoom) {
        google.maps.event.addListenerOnce(map, 'bounds_changed', function () {
            if (this.getZoom() > zoom) {
                this.setZoom(zoom);
            }
        });
    }
}

function addMarkersToMap(markers, map) {
    var hasMultipleMarkers = markers.length > 1;
    var bounds = new google.maps.LatLngBounds();
    var googleMarkers = [];
    markers.forEach(function (marker) {
        var latLng = new google.maps.LatLng(marker.lat, marker.lng);
        var title = marker.title;
        googleMarkers.push(createMarker(map, latLng, title, hasMultipleMarkers));
        bounds = bounds.extend(latLng);
    });

    zoomToBounds(map, bounds, hasMultipleMarkers ? null : 14);

    return googleMarkers;
}

function getFieldLat() {
    return $('#site_latitude').val();
}
function setFieldLat(value) {
    $('#site_latitude').val(value);
}
function getFieldLng() {
    return $('#site_longitude').val();
}
function setFieldLng(value) {
    $('#site_longitude').val(value);
}
function onFieldLatLngChange(){
    $('#site_latitude').bind('change', fieldLatLngChange);
    $('#site_longitude').bind('change', fieldLatLngChange);
}
function getFieldLatLng() {
    return new google.maps.LatLng(Number(getFieldLat()), Number(getFieldLng()));
}
function setFieldLatLng(latLng) {
    setFieldLat(latLng.lat().toFixed(6));
    setFieldLng(latLng.lng().toFixed(6));
}
function fieldLatLngChange() {
    var newLatLng = getFieldLatLng();
    if (newLatLng.lat() != 0 || newLatLng.lng() != 0) {
        setLocationMarker.setPosition(newLatLng);
        setLocationMarker.getMap().setCenter(newLatLng);
    }
}

function initMap() {
    var markers = markersArray;
    var isEditing = markers.length < 1;
    var isViewSingle = markers.length == 1;
    var isViewMultiple = markers.length > 1;

    onFieldLatLngChange();

    var initialLatLng = isEditing ? getFieldLatLng() : {lat: -27.4667, lng: 153.0333};
    var map = new google.maps.Map(document.getElementById('siteLocationMap'), {
        center: initialLatLng,
        zoom: 9,
        mapTypeId: google.maps.MapTypeId.HYBRID
    });

    if (isEditing) {
        var marker = createMarker(map, initialLatLng, null, true, true);

        var bounds = new google.maps.LatLngBounds();
        bounds = bounds.extend(marker.getPosition());
        zoomToBounds(map, bounds, 14);

    } else {
        addMarkersToMap(markers, map);
    }
}
