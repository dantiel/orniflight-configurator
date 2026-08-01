DEFAULT_ZOOM = 16
DEFAULT_LON = 0
DEFAULT_LAT = 0
ICON_IMAGE = '/images/icons/cf_icon_position.png'
ICON_IMAGE_NOFIX = '/images/icons/cf_icon_position_nofix.png'
iconGeometry = undefined
map = undefined
mapView = undefined
iconStyle = undefined
iconStyleNoFix = undefined
iconFeature = undefined

initializeMap = ->
    lonLat = ol.proj.fromLonLat([
        DEFAULT_LON
        DEFAULT_LAT
    ])
    mapView = new (ol.View)(
        center: lonLat
        zoom: DEFAULT_ZOOM)
    map = new (ol.Map)(
        target: 'map-canvas'
        layers: [ new (ol.layer.Tile)(source: new (ol.source.OSM)) ]
        view: mapView
        controls: [])
    icon = new (ol.style.Icon)(
        anchor: [
            0.5
            1
        ]
        opacity: 1
        scale: 0.5
        src: ICON_IMAGE)
    iconNoFix = new (ol.style.Icon)(
        anchor: [
            0.5
            1
        ]
        opacity: 1
        scale: 0.5
        src: ICON_IMAGE_NOFIX)
    iconStyle = new (ol.style.Style)(image: icon)
    iconStyleNoFix = new (ol.style.Style)(image: iconNoFix)
    iconGeometry = new (ol.geom.Point)(lonLat)
    iconFeature = new (ol.Feature)(geometry: iconGeometry)
    iconFeature.setStyle iconStyle
    vectorSource = new (ol.source.Vector)(features: [ iconFeature ])
    currentPositionLayer = new (ol.layer.Vector)(source: vectorSource)
    map.addLayer currentPositionLayer
    window.addEventListener 'message', processMapEvents
    return

processMapEvents = (e) ->
    try
        switch e.data.action
            when 'zoom_in'
                mapView.setZoom mapView.getZoom() + 1
            when 'zoom_out'
                mapView.setZoom mapView.getZoom() - 1
            when 'center'
                iconFeature.setStyle iconStyle
                center = ol.proj.fromLonLat([
                    e.data.lon
                    e.data.lat
                ])
                mapView.setCenter center
                iconGeometry.setCoordinates center
            when 'nofix'
                iconFeature.setStyle iconStyleNoFix
    catch e
        console.log 'Map error ' + e
    return

window.onload = initializeMap

