// 🎯 Dart imports:
import 'dart:async';
import 'dart:convert';

// 🐦 Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 📦 Package imports:
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';
import 'package:location/location.dart' as gps;
import 'package:screenshot/screenshot.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

// 🌎 Project imports:
import 'package:navika/src/api.dart';
import 'package:navika/src/controller/here_map_controller.dart';
import 'package:navika/src/data/global.dart' as globals;
import 'package:navika/src/icons/navika_icons_icons.dart';
import 'package:navika/src/routing/route_state.dart';
import 'package:navika/src/screens/home_search.dart';
import 'package:navika/src/style.dart';
import 'package:navika/src/utils.dart';
import 'package:navika/src/widgets/home/header.dart';
import 'package:navika/src/widgets/home/pannel.dart';
import 'package:navika/src/widgets/map/icone.dart';

class Home extends StatefulWidget {
  final String? displayType;
  final String? id;

  const Home({
    this.displayType,
    this.id,
    super.key,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  HereController? _controller;
  PanelController panelController = PanelController();

  GeoCoordinates camGeoCoords = GeoCoordinates(0, 0);
  gps.Location location = gps.Location();

  late StreamSubscription<ConnectivityResult> connection;

  CompassEvent? compassEvent;
  double compassHeading = 0;

  bool isPanned = false;
  bool is3dMap = false;
  bool _isInBox = false;
  late Timer _timer;
  bool isConnected = true;

  double panelButtonBottomOffsetClosed = 120;
  double panelButtonBottomOffset = 120;
  double _position = 0;

  GeoCoordinates _oldcamGeoCoords = GeoCoordinates(0, 0);
  ScreenshotController screenshotController = ScreenshotController();

  Map markersList = {}; //Update List<WidgetPin> markers = [];
  Map index = {};

  dynamic _data;
  double _padding = 0;

  Future<void> _getLocation(isResume) async {
    bool serviceEnabled;
    gps.LocationData locationData;

    bool? askGps = await globals.hiveBox?.get('askGps');
    bool? allowGps = await globals.hiveBox?.get('allowGps');
    if (askGps == false) {
      RouteStateScope.of(context).go('/position');
      return;
    }

    if (allowGps == false) {
      return;
    }

    if (!globals.isSetLocation) {
      serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          RouteStateScope.of(context).go('/position');
          return;
        }
      }
    }

    locationData = await location.getLocation();
    camGeoCoords = GeoCoordinates(locationData.latitude ?? 0, locationData.longitude ?? 0);

    if (mounted) {
      FlutterCompass.events?.listen((CompassEvent compassEvent) {
        _updateCompass(compassEvent);
      });
      if (!isResume) {
        _addLocationIndicator(locationData);
      }
      location.onLocationChanged.listen((gps.LocationData currentLocation) {
        _updateLocationIndicator(currentLocation);
      });
      await _getNearPoints();
    }
  }

  Future<void> _getNearPoints() async {
    double zoom = _controller?.getZoomLevel() ?? 0;

    if (_oldcamGeoCoords == camGeoCoords) {
      return;
    }
    _oldcamGeoCoords = camGeoCoords;

    List bikeNearby = [];
    List stopsNearby = [];
    List areaNearby = [];

    if (zoom < 200000) {
      NavikaApi navikaApi = NavikaApi();
      Map result = await navikaApi.getNearPoints(zoom, camGeoCoords);

      if (result['status'] == ApiStatus.ok && mounted) {
        setState(() {
          if (result['value']?['stops'] != null) {
            stopsNearby = result['value']?['stops'];
          } else {
            stopsNearby = [];
          }

          if (result['value']?['area'] != null) {
            areaNearby = result['value']?['area'];
          } else {
            areaNearby = [];
          }

          if (result['value']?['bike'] != null) {
            bikeNearby = result['value']?['bike'];
          } else {
            bikeNearby = [];
          }
        });
      }
      setState(() {
        markersList = _setMarker(markersList, bikeNearby, stopsNearby, areaNearby);
      });
    } else {
      _clearMarker(markersList);
      setState(() {
        markersList = {};
      });
    }
  }

  void _clearMarker(Map markers) {
    markers.forEach((key, value) {
      if (value is MapMarker) {
        _controller?.removeMapMarker(value);
      }
    });
  }

  Map _setMarker(Map markers, List bikeNearby, List stopsNearby, List areaNearby) {
    Map newMarkers = Map.from(markers);

    for (var bike in bikeNearby) {
      GeoCoordinates bikeCoords = GeoCoordinates(bike['coord']['lat'].toDouble(), bike['coord']['lon'].toDouble());

      if (_controller?.isOverLocation(bikeCoords) == true) {
        Metadata metadata = Metadata();
        metadata.setString('type', 'bike');
        metadata.setString('id', bike['id']);
        metadata.setString('name', bike['name']);
        metadata.setInteger('capacity', bike['capacity']);
        metadata.setDouble('lat', bike['coord']['lat']);
        metadata.setDouble('lon', bike['coord']['lon']);

        MarkerMode mode = getMarkerMode(['bike']);
        double zoom = _controller?.getZoomLevel() ?? 1000;
        MarkerSize size = getMarkerSize(mode, zoom);

        if (size != MarkerSize.hidden) {
          if (newMarkers[bike['id']] == null) {
            newMarkers[bike['id']] = _controller?.addMapMarker(bikeCoords, getMarkerImageByType(mode, size, context), metadata, getSizeForMarker(size));
          } else {
            markers.remove(bike['id']);
            newMarkers.remove(bike['id']);
          }
        }
      }
    }

    for (var stop in stopsNearby) {
      GeoCoordinates stopCoords = GeoCoordinates(stop['coord']['lat'].toDouble(), stop['coord']['lon'].toDouble());

      if (_controller?.isOverLocation(stopCoords) == true) {
        Metadata metadata = Metadata();
        metadata.setString('type', 'stop');
        metadata.setString('id', stop['id']);
        metadata.setString('name', stop['name']);
        metadata.setString('modes', json.encode(stop['modes']));
        metadata.setDouble('lat', stop['coord']['lat'].toDouble());
        metadata.setDouble('lon', stop['coord']['lon'].toDouble());

        MarkerMode mode = getMarkerMode(stop['modes']);
        double zoom = _controller?.getZoomLevel() ?? 1000;
        MarkerSize size = getMarkerSize(mode, zoom);

        String id = '${stop['id']}_${size.toString()}';

        if (size != MarkerSize.hidden) {
          if (newMarkers[id] == null) {
            newMarkers[id] = _controller?.addMapMarker(stopCoords, getMarkerImageByType(mode, size, context), metadata, getSizeForMarker(size));
          } else {
            markers.remove(id);
          }
        }
      }
    }

    for (var area in areaNearby) {
      area['stops'].forEach((stop) {
        GeoCoordinates stopCoords = GeoCoordinates(stop['coord']['lat'].toDouble(), stop['coord']['lon'].toDouble());

        Metadata metadata = Metadata();
        metadata.setString('type', 'stop');
        metadata.setString('id', stop['id']);
        metadata.setString('name', stop['name']);
        metadata.setString('modes', json.encode(stop['modes']));
        metadata.setDouble('lat', stop['coord']['lat'].toDouble());
        metadata.setDouble('lon', stop['coord']['lon'].toDouble());

        if (newMarkers[stop['id']] == null) {
          screenshotController
              .captureFromWidget(
                  MapIcone(
                    stop: stop,
                    brightness: Theme.of(context).colorScheme.brightness,
                    update: () {},
                  ),
                  delay: const Duration(milliseconds: 0))
              .then((capturedImage) {
            newMarkers[stop['id']] = _controller?.addMapImage(stopCoords, capturedImage, metadata);
          });
        } else {
          markers.remove(stop['id']);
        }
      });
    }

    markers.forEach((key, value) {
      if (value is MapMarker) {
        _controller?.removeMapMarker(value);
      }
      newMarkers.remove(key);
    });

    return newMarkers;
  }

  Future<void> _getIndex() async {
    if (globals.index != null) {
      setState(() {
        index = globals.index!;
      });
      return;
    }

    NavikaApi navikaApi = NavikaApi();
    Map result = await navikaApi.getIndex();

    if (result['status'] == ApiStatus.ok && mounted) {
      setState(() {
        index = result['value']!;
      });
      globals.index = result['value']!;
    }
  }

  void setData(data) {
    setState(() {
      _data = data;
    });
  }

  void setPadding(padding) {
    setState(() {
      _padding = padding;
    });
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).colorScheme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          body: Stack(
            alignment: Alignment.topCenter,
            children: [
              SlidingUpPanel(
                parallaxEnabled: true,
                parallaxOffset: 0.6,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
                snapPoint: 0.55,
                minHeight: 90,
                maxHeight: availableHeight(context),
                controller: panelController,
                onPanelSlide: (position) => _onPanelSlide(position),
                header: HomeHeader(
                  id: widget.id,
                  type: widget.displayType,
                  data: _data,
                  padding: _padding,
                  removePointMarker: removePointMarker,
                  setData: setData,
                  setPadding: setPadding,
                  panelController: panelController,
                ),
                panelBuilder: (ScrollController scrollController) => HomePannel(
                  id: widget.id,
                  type: widget.displayType,
                  scrollController: scrollController,
                  index: index,
                  data: _data,
                  padding: _padding,
                  setData: setData,
                  setPadding: setPadding,
                  panelController: panelController,
                ),
                body: HereMap(onMapCreated: _onMapCreated),
              ),
              if (!isConnected)
                Positioned(
                  top: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    color: Colors.amber,
                    child: SafeArea(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, left: 73, bottom: 15),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/img/cloud_off.svg',
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.of(context)!.no_internet_connection,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: fontFamily,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // if (widget.id != null && widget.displayType != null)
              //   Positioned(
              //     top: 0,
              //     left: 0,
              //     child: Opacity(
              //       opacity: getOpacity(_position),
              //       child: SafeArea(
              //         child: Container(
              //           margin: const EdgeInsets.only(top: 10, left: 8, right: 8),
              //           width: getSearchWidth(_position, context),
              //           height: 45,
              //           child: Material(
              //             borderRadius: BorderRadius.circular(500),
              //             elevation: 4.0,
              //             shadowColor: Colors.black.withOpacity(getOpacity(_position)),
              //             color: Theme.of(context).colorScheme.surface,
              //             child: SearchBox(
              //                 onTap: () {
              //                   RouteStateScope.of(context).go('/home/search');
              //                 },
              //                 color: Theme.of(context).colorScheme.surface,
              //                 padding: const EdgeInsets.only(left: 10, right: 10),
              //                 icon: NavikaIcons.search,
              //                 text: AppLocalizations.of(context)!.search_location_on_map),
              //           ),
              //         ),
              //       ),
              //     ),
              //   ),
              Positioned(
                top: 0,
                right: 0,
                child: Opacity(
                  opacity: getOpacity(_position),
                  child: SafeArea(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, right: 8),
                      width: 45,
                      height: 45,
                      child: Material(
                        borderRadius: BorderRadius.circular(500),
                        elevation: 4.0,
                        shadowColor: Colors.black.withOpacity(getOpacity(_position)),
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(500),
                          onTap: () {
                            RouteStateScope.of(context).go('/settings');
                          },
                          child: Icon(
                            NavikaIcons.settingsFilled,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: panelButtonBottomOffset,
                child: Opacity(
                  opacity: getOpacity(_position),
                  child: FloatingActionButton(
                    backgroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                    child: _isInBox
                        ? Icon(NavikaIcons.localisation, color: Theme.of(context).colorScheme.onSurface, size: 30)
                        : Icon(NavikaIcons.localisationNull, color: Theme.of(context).colorScheme.onSurface, size: 30),
                    onPressed: () {
                      _zoomOn();
                      _closePanel();
                    },
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: panelButtonBottomOffset - 20,
                child: Opacity(
                  opacity: getOpacity(_position),
                  child: SvgPicture.asset(
                    hereIcon(context),
                    width: 50,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getIndex();
      _getNearPoints();
      _getInBox();
      panelController.animatePanelToSnapPoint();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _getInBox();
      });
      _initializeConnectivity();
      connection = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
        _setConnectivity(result);
      });
    });
  }

  @override
  void didUpdateWidget(Home oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id || widget.displayType != oldWidget.displayType) {
      setState(() {
        setData(null);
        setPadding(0.0);
      });
    }
  }

  @override
  void dispose() async {
    super.dispose();
    globals.isSetLocation = false;
    connection.cancel();
    _timer.cancel();
  }

  void _getInBox() {
    GeoCoordinates geoCoords = GeoCoordinates(globals.locationData?.latitude ?? 0, globals.locationData?.longitude ?? 0);
    setState(() {
      _isInBox = _controller?.isOverLocation(geoCoords) ?? false;
    });
  }

  void _onMapCreated(HereMapController hereMapController) {
    //THEME
    MapScheme mapScheme = Brightness.dark == Theme.of(context).colorScheme.brightness ? MapScheme.normalNight : MapScheme.normalDay;

    hereMapController.mapScene.loadSceneForMapScheme(mapScheme, (MapError? error) {
      if (error != null) {
        return;
      }

      _controller = HereController(hereMapController);
      globals.hereMapController = _controller;
      globals.panelController = panelController;
      _getLocation(globals.isSetLocation);

      GeoCoordinates geoCoords;
      double distanceToEarthInMeters = 10000;
      if (globals.isSetLocation) {
        // Resume Map
        geoCoords = GeoCoordinates(globals.locationData?.latitude ?? 48.859481, globals.locationData?.longitude ?? 2.346711);
        distanceToEarthInMeters = 1000;
      } else if (globals.hiveBox?.get('latitude') != null && globals.hiveBox?.get('longitude') != null) {
        // Opening App
        geoCoords = GeoCoordinates(globals.hiveBox.get('latitude'), globals.hiveBox.get('longitude'));
        distanceToEarthInMeters = 10000;
      } else {
        geoCoords = GeoCoordinates(48.859481, 2.346711);
        _controller?.addLocationIndicator(globals.locationData, LocationIndicatorIndicatorStyle.pedestrian, globals.compassHeading, true);
      }

      MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
      hereMapController.camera.lookAtPointWithMeasure(geoCoords, mapMeasureZoom);

      hereMapController.gestures.tapListener = TapListener((Point2D touchPoint) {
        _tapListener(touchPoint);
      });

      hereMapController.gestures.panListener = PanListener((GestureState state, Point2D origin, Point2D translation, double velocity) {
        if (mounted) {
          if (state == GestureState.begin) {
            setState(() {
              isPanned = true;
            });
          }
          if (state == GestureState.end) {
            setState(() {
              camGeoCoords = _controller?.getOverLocation() ?? camGeoCoords;
            });
            _getNearPoints();
          }
        }
      });

      hereMapController.gestures.pinchRotateListener =
          PinchRotateListener((GestureState state, Point2D pinchOrigin, Point2D rotationOrigin, double twoFingerDistance, Angle rotation) {
        if (state == GestureState.end) {
          setState(() {
            camGeoCoords = _controller?.getOverLocation() ?? camGeoCoords;
          });
          _getNearPoints();
        }
      });

      _controller?.addLocationIndicator(globals.locationData, LocationIndicatorIndicatorStyle.pedestrian, globals.compassHeading, false);
      _getNearPoints();
    });
  }

  void _tapListener(Point2D touchPoint) {
    double radiusInPixel = 2;
    _controller?.pickMapItems(touchPoint, radiusInPixel, (pickMapItemsResult) {
      if (pickMapItemsResult == null || pickMapItemsResult.markers.isEmpty) {
        GeoCoordinates geoCoordinates = _controller!.viewToGeoCoordinates(touchPoint);
        GeoCoordinatesUpdate geoCoords = GeoCoordinatesUpdate(geoCoordinates.latitude, geoCoordinates.longitude);
        _controller?.zoomTo(geoCoords, true);
        globals.updateMap = true;

        removePointMarker();
        globals.pointMarker = _controller?.addMapMarker(
          geoCoordinates,
          'assets/img/marker/marker.png',
          Metadata(),
          100,
        );
        RouteStateScope.of(context).go('/address/${geoCoordinates.latitude};${geoCoordinates.longitude}');
      } else {
        List<MapMarker> mapMarkerList = pickMapItemsResult.markers;
        MapMarker topmostMapMarker = mapMarkerList.first;
        Metadata? metadata = topmostMapMarker.metadata;
        if (metadata == null) {
          return;
        }

        if (mounted) {
          setState(() {
            isPanned = true;
          });
        }

        if (metadata.getString('type') == 'stop') {
          GeoCoordinatesUpdate geoCoords = GeoCoordinatesUpdate(metadata.getDouble('lat') ?? 0, metadata.getDouble('lon') ?? 0);
          _controller?.zoomTo(geoCoords, true);
          globals.updateMap = true;
          RouteStateScope.of(context).go('/stops/${metadata.getString('id')}');
        } else if (metadata.getString('type') == 'bike') {
          GeoCoordinatesUpdate geoCoords = GeoCoordinatesUpdate(metadata.getDouble('lat') ?? 0, metadata.getDouble('lon') ?? 0);
          _controller?.zoomTo(geoCoords, true);
          globals.updateMap = true;
          RouteStateScope.of(context).go('/bike/${metadata.getString('id')}');
        }
      }
    });
  }

  void _addLocationIndicator(gps.LocationData locationData) {
    _controller?.addLocationIndicator(locationData, LocationIndicatorIndicatorStyle.pedestrian, globals.compassHeading);
  }

  void _updateLocationIndicator(gps.LocationData locationData) async {
    _controller?.updateLocationIndicator(locationData, globals.compassHeading);
    await _getNearPoints();
  }

  void _updateCompass(CompassEvent compassEvent) {
    var heading = compassEvent.heading ?? 0;
    if (mounted) {
      setState(() {
        compassHeading = heading;
      });
    }
    globals.compassHeading = heading;

    if (is3dMap) {
      if (!isPanned) {
        // si on a touché l'écran
        _controller?.zoomOnLocationIndicator(is3dMap);
      }
    }
    _controller?.updateLocationIndicator(globals.locationData, heading);
  }

  void _zoomOn() {
    GeoCoordinates geoCoords = GeoCoordinates(globals.locationData?.latitude ?? 0, globals.locationData?.longitude ?? 0);
    var isOverLocation = _controller?.isOverLocation(geoCoords) ?? false;
    if (isOverLocation) {
      setState(() {
        is3dMap = !is3dMap;
        isPanned = false;
      });
    }
    _controller?.zoomOnLocationIndicator(is3dMap);
  }

  void _onPanelSlide(position) {
    setState(() {
      panelButtonBottomOffset = panelButtonBottomOffsetClosed + ((MediaQuery.of(context).size.height - 230) * position);
      _position = position;
    });
  }

  void _closePanel() {
    panelController.close();
  }

  Future<void> _initializeConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    _setConnectivity(connectivityResult);
  }

  void _setConnectivity(connectivity) {
    setState(() {
      isConnected = !(connectivity == ConnectivityResult.none);
    });
  }
}
