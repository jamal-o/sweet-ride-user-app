import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_user/pages/onTripPage/choosegoods.dart';
import 'package:geolocator/geolocator.dart' as geolocs;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

import '../../functions/functions.dart';
import '../../styles/styles.dart';
import '../../translations/translation.dart';
import '../../widgets/widgets.dart';
import '../loadingPage/loading.dart';
import '../login/login.dart';
import 'package:flutter_user/pages/noInternet/nointernet.dart';
import 'booking_confirmation.dart';
import 'map_page.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
// ignore: depend_on_referenced_packages
import 'package:latlong2/latlong.dart' as fmlt;

// ignore: must_be_immutable
class PickupLocation extends StatefulWidget {
  dynamic from;
  String? favName;
  PickupLocation({super.key, this.from, this.favName});

  @override
  State<PickupLocation> createState() => _PickupLocationState();
}

class _PickupLocationState extends State<PickupLocation>
    with WidgetsBindingObserver {
  GoogleMapController? _controller;
  final fm.MapController _fmController = fm.MapController();
  late PermissionStatus permission;
  Location location = Location();
  String _state = '';
  bool _isLoading = false;
  dynamic _sessionToken;
  LatLng _center = const LatLng(41.4219057, -102.0840772);
  LatLng _centerLocation = const LatLng(41.4219057, -102.0840772);
  TextEditingController search = TextEditingController();
  String favNameText = '';
  bool _locationDenied = false;
  bool favAddressAdd = false;
  bool _getDropDetails = false;
  TextEditingController buyerName = TextEditingController();
  TextEditingController buyerNumber = TextEditingController();
  TextEditingController instructions = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 1000);
  bool useMyDetails = false;
  bool useMyAddress = false;

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _controller = controller;
      _controller?.setMapStyle(mapStyle);
    });
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    dropAddressConfirmation = '';
    useMyDetails = false;

    getLocs();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (isDarkTheme == true) {
      await rootBundle.loadString('assets/dark.json').then((value) {
        mapStyle = value;
      });
    } else {
      await rootBundle.loadString('assets/map_style_black.json').then((value) {
        mapStyle = value;
      });
    }
    if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        _controller?.setMapStyle(mapStyle);
        valueNotifierHome.incrementNotifier();
      }
      if (locationAllowed == true) {
        if (positionStream == null || positionStream!.isPaused) {
          positionStreamData();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;

    super.dispose();
  }

  getLocs() async {
    permission = await location.hasPermission();

    if (permission == PermissionStatus.denied ||
        permission == PermissionStatus.deniedForever) {
      setState(() {
        _state = '3';
        _isLoading = false;
      });
    } else if (permission == PermissionStatus.granted ||
        permission == PermissionStatus.grantedLimited) {
      var locs = await geolocs.Geolocator.getLastKnownPosition();
      if (addressList.length != 2 && widget.from == null) {
        if (locs != null) {
          setState(() {
            _center = LatLng(double.parse(locs.latitude.toString()),
                double.parse(locs.longitude.toString()));
            _centerLocation = LatLng(double.parse(locs.latitude.toString()),
                double.parse(locs.longitude.toString()));
          });
        } else {
          var loc = await geolocs.Geolocator.getCurrentPosition(
              desiredAccuracy: geolocs.LocationAccuracy.low);
          setState(() {
            _center = LatLng(double.parse(loc.latitude.toString()),
                double.parse(loc.longitude.toString()));
            _centerLocation = LatLng(double.parse(loc.latitude.toString()),
                double.parse(loc.longitude.toString()));
          });
        }
        setState(() {
          _center = addressList[0].latlng;
          // dropAddressConfirmation = addressList[0].address;
          pickupAddressConfirmation = addressList[0].address;
        });
      } else if (widget.from != null &&
          widget.from != 'add stop' &&
          widget.from != 'favourite') {
        setState(() {
          buyerName.text = addressList[widget.from].name.toString();
          buyerNumber.text = addressList[widget.from].number.toString();
          instructions.text = (addressList[widget.from].instructions != null)
              ? addressList[widget.from].instructions
              : '';
          _center = addressList[widget.from].latlng;
          _centerLocation = addressList[widget.from].latlng;
          // dropAddressConfirmation = addressList[widget.from].address;
          pickupAddressConfirmation = addressList[widget.from].address;
        });
      } else if (widget.from != null && widget.from == 'favourite') {
        var loc = await geolocs.Geolocator.getCurrentPosition(
            desiredAccuracy: geolocs.LocationAccuracy.low);
        setState(() {
          _center = LatLng(double.parse(loc.latitude.toString()),
              double.parse(loc.longitude.toString()));
          _centerLocation = LatLng(double.parse(loc.latitude.toString()),
              double.parse(loc.longitude.toString()));
        });
      } else if (widget.from == 'add stop') {
        if (locs != null) {
          setState(() {
            _center = LatLng(double.parse(locs.latitude.toString()),
                double.parse(locs.longitude.toString()));
            _centerLocation = LatLng(double.parse(locs.latitude.toString()),
                double.parse(locs.longitude.toString()));
          });
        } else {
          var loc = await geolocs.Geolocator.getCurrentPosition(
              desiredAccuracy: geolocs.LocationAccuracy.low);
          setState(() {
            _center = LatLng(double.parse(loc.latitude.toString()),
                double.parse(loc.longitude.toString()));
            _centerLocation = LatLng(double.parse(loc.latitude.toString()),
                double.parse(loc.longitude.toString()));
          });
        }
        setState(() {
          _center = addressList.firstWhere((e) => e.type == 'pickup').latlng;
          _centerLocation =
              addressList.firstWhere((e) => e.type == 'pickup').latlng;
          // dropAddressConfirmation
          pickupAddressConfirmation = addressList
              .firstWhere((element) => element.type == 'pickup')
              .address;

          useMyAddress = true;
        });
      } else {
        setState(() {
          _center = addressList.firstWhere((e) => e.type == 'pickup').latlng;
          _centerLocation =
              addressList.firstWhere((e) => e.type == 'pickup').latlng;
          // if (addressList.length >= 2) {
          //   dropAddressConfirmation = addressList
          //       .firstWhere((element) => element.type == 'drop')
          //       .address;
          // }
          useMyAddress = true;
        });
      }

      setState(() {
        _state = '3';
        _isLoading = false;
      });
    }
  }

  navigateLogout() {
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
        (route) => false);
  }

  popFunction() {
    if (_getDropDetails == true) {
      return false;
    } else {
      addressList.removeWhere((element) => element.id == 'pickup');
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return PopScope(
      canPop: popFunction(),
      onPopInvoked: (did) {
        if (_getDropDetails) {
          setState(() {
            _getDropDetails = false;
          });
        }
      },
      child: SafeArea(
        child: Material(
          child: ValueListenableBuilder(
              valueListenable: valueNotifierHome.value,
              builder: (context, value, child) {
                return Directionality(
                  textDirection: (languageDirection == 'rtl')
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: Container(
                    height: media.height * 1,
                    width: media.width * 1,
                    color: page,
                    child: Stack(
                      children: [
                        SizedBox(
                          height: media.height * 1,
                          width: media.width * 1,
                          child: (_state == '3')
                              ? (mapType == 'google')
                                  ? GoogleMap(
                                      onMapCreated: _onMapCreated,
                                      initialCameraPosition: CameraPosition(
                                        target: _center,
                                        zoom: 14.0,
                                      ),
                                      onCameraMove: (CameraPosition position) {
                                        //pick current location
                                        // setState(() {
                                        _centerLocation = position.target;
                                        // });
                                      },
                                      onCameraIdle: () async {
                                        if (userDetails[
                                                'enable_map_location_icon_drag_and_drop_feature'] ==
                                            '0') {
                                          if (pickupAddressConfirmation != '') {
                                            setState(() {});
                                          } else {
                                            if (useMyAddress == false) {
                                              var val = await geoCoding(
                                                  _centerLocation.latitude,
                                                  _centerLocation.longitude);
                                              setState(() {
                                                _center = _centerLocation;
                                                pickupAddressConfirmation = val;
                                              });
                                            }
                                            if (useMyAddress == true) {
                                              setState(() {
                                                useMyAddress = false;
                                              });
                                            }
                                          }
                                        } else {
                                          if (useMyAddress == false) {
                                            var val = await geoCoding(
                                                _centerLocation.latitude,
                                                _centerLocation.longitude);
                                            setState(() {
                                              _center = _centerLocation;
                                              pickupAddressConfirmation = val;
                                            });
                                          }
                                          if (useMyAddress == true) {
                                            setState(() {
                                              useMyAddress = false;
                                            });
                                          }
                                        }
                                      },
                                      minMaxZoomPreference:
                                          const MinMaxZoomPreference(8.0, 20.0),
                                      myLocationButtonEnabled: false,
                                      buildingsEnabled: false,
                                      zoomControlsEnabled: false,
                                      myLocationEnabled: true,
                                    )
                                  : fm.FlutterMap(
                                      mapController: _fmController,
                                      options: fm.MapOptions(
                                          onMapEvent: (v) async {
                                            if (v.source ==
                                                    fm.MapEventSource
                                                        .nonRotatedSizeChange &&
                                                addressList.isEmpty) {
                                              _centerLocation = LatLng(
                                                  v.camera.center.latitude,
                                                  v.camera.center.longitude);
                                              setState(() {});

                                              var val = await geoCoding(
                                                  _centerLocation.latitude,
                                                  _centerLocation.longitude);
                                              if (val != '') {
                                                setState(() {
                                                  _center = _centerLocation;
                                                  pickupAddressConfirmation =
                                                      val;
                                                });
                                              }
                                            }
                                            if (v.source ==
                                                fm.MapEventSource.dragEnd) {
                                              _centerLocation = LatLng(
                                                  v.camera.center.latitude,
                                                  v.camera.center.longitude);
                                              if (userDetails[
                                                      'enable_map_location_icon_drag_and_drop_feature'] ==
                                                  '1') {
                                                var val = await geoCoding(
                                                    _centerLocation.latitude,
                                                    _centerLocation.longitude);
                                                if (val != '') {
                                                  setState(() {
                                                    _center = _centerLocation;
                                                    dropAddressConfirmation =
                                                        val;
                                                  });
                                                }
                                              }
                                            }
                                          },
                                          onPositionChanged: (p, l) async {
                                            if (l == false) {
                                              _centerLocation = LatLng(
                                                  p.center.latitude,
                                                  p.center.longitude);
                                              setState(() {});

                                              var val = await geoCoding(
                                                  _centerLocation.latitude,
                                                  _centerLocation.longitude);
                                              if (val != '') {}
                                            }
                                          },
                                          // ignore: deprecated_member_use
                                          // interactiveFlags:
                                          //     ~fm.InteractiveFlag.doubleTapZoom,
                                          initialCenter: fmlt.LatLng(
                                              center.latitude,
                                              center.longitude),
                                          initialZoom: 16,
                                          onTap: (P, L) {
                                            setState(() {});
                                          }),
                                      children: [
                                        fm.TileLayer(
                                          // minZoom: 10,
                                          urlTemplate:
                                              // 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                              (isDarkTheme == false)
                                                  ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                                                  : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                                          userAgentPackageName: 
                                          'com.example.app',
                                        ),
                                        const fm.RichAttributionWidget(
                                          attributions: [],
                                        ),
                                      ],
                                    )
                              : (_state == '2')
                                  ? Container(
                                      height: media.height * 1,
                                      width: media.width * 1,
                                      alignment: Alignment.center,
                                      child: Container(
                                        padding:
                                            EdgeInsets.all(media.width * 0.05),
                                        width: media.width * 0.6,
                                        height: media.width * 0.3,
                                        decoration: BoxDecoration(
                                            color: page,
                                            boxShadow: [
                                              BoxShadow(
                                                  blurRadius: 5,
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  spreadRadius: 2)
                                            ],
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              languages[choosenLanguage]
                                                  ['text_loc_permission'],
                                              style: GoogleFonts.notoSans(
                                                  fontSize:
                                                      media.width * sixteen,
                                                  color: textColor,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            Container(
                                              alignment: Alignment.centerRight,
                                              child: InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    _state = '';
                                                  });
                                                  await location
                                                      .requestPermission();
                                                  getLocs();
                                                },
                                                child: Text(
                                                  languages[choosenLanguage]
                                                      ['text_ok'],
                                                  style: GoogleFonts.notoSans(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          media.width * twenty,
                                                      color: buttonColor),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    )
                                  : Container(),
                        ),
                        Positioned(
                            child: Container(
                          height: media.height * 1,
                          width: media.width * 1,
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              SizedBox(
                                height: (media.height / 2) - media.width * 0.08,
                              ),
                              Image.asset(
                                'assets/images/dropmarker.png',
                                width: media.width * 0.07,
                                height: media.width * 0.08,
                              ),
                              if (userDetails[
                                      'enable_map_location_icon_drag_and_drop_feature'] ==
                                  '0')
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Button(
                                      width: media.width * 0.5,
                                      onTap: () async {
                                        setState(() {
                                          _isLoading = true;
                                        });
                                        if (useMyAddress == false) {
                                          var val = await geoCoding(
                                              _centerLocation.latitude,
                                              _centerLocation.longitude);
                                          setState(() {
                                            _center = _centerLocation;
                                            dropAddressConfirmation = val;
                                            _isLoading = false;
                                          });
                                        }
                                        if (useMyAddress == true) {
                                          setState(() {
                                            useMyAddress = false;
                                          });
                                        }
                                      },
                                      text: languages[choosenLanguage]
                                          ['text_confirm'],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        )),
                        Positioned(
                            bottom:
                                0 + MediaQuery.of(context).viewInsets.bottom,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(
                                      right: 20, left: 20),
                                  child: InkWell(
                                    onTap: () async {
                                      if (locationAllowed == true) {
                                        if (currentLocation != null) {
                                          _controller?.animateCamera(
                                              CameraUpdate.newLatLngZoom(
                                                  currentLocation, 18.0));
                                          center = currentLocation;
                                        } else {
                                          _controller?.animateCamera(
                                              CameraUpdate.newLatLngZoom(
                                                  center, 18.0));
                                        }
                                      } else {
                                        if (serviceEnabled == true) {
                                          setState(() {
                                            _locationDenied = true;
                                          });
                                        } else {
                                          // await location.requestService();
                                          await geolocs.Geolocator
                                              .getCurrentPosition(
                                                  desiredAccuracy: geolocs
                                                      .LocationAccuracy.low);
                                          if (await geolocs
                                              .GeolocatorPlatform.instance
                                              .isLocationServiceEnabled()) {
                                            setState(() {
                                              _locationDenied = true;
                                            });
                                          }
                                        }
                                      }
                                    },
                                    child: Container(
                                      height: media.width * 0.1,
                                      width: media.width * 0.1,
                                      decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                                blurRadius: 2,
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                spreadRadius: 2)
                                          ],
                                          color: page,
                                          borderRadius: BorderRadius.circular(
                                              media.width * 0.02)),
                                      child: Icon(Icons.my_location_sharp,
                                          color: textColor),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: media.width * 0.1,
                                ),
                                Container(
                                  color: page,
                                  width: media.width * 1,
                                  padding: EdgeInsets.all(media.width * 0.05),
                                  child: Column(
                                    children: [
                                      Container(
                                          padding: EdgeInsets.fromLTRB(
                                              media.width * 0.03,
                                              media.width * 0.01,
                                              media.width * 0.03,
                                              media.width * 0.01),
                                          height: media.width * 0.1,
                                          width: media.width * 0.9,
                                          decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey,
                                                width: 1.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      media.width * 0.02),
                                              color: page),
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            children: [
                                              Container(
                                                height: media.width * 0.04,
                                                width: media.width * 0.04,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color:
                                                        const Color(0xffFF0000)
                                                            .withOpacity(0.3)),
                                                child: Container(
                                                  height: media.width * 0.02,
                                                  width: media.width * 0.02,
                                                  decoration:
                                                      const BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: Color(
                                                              0xffFF0000)),
                                                ),
                                              ),
                                              SizedBox(
                                                  width: media.width * 0.02),
                                              Expanded(
                                                child:
                                                    (pickupAddressConfirmation ==
                                                            '')
                                                        ? Text(
                                                            languages[
                                                                    choosenLanguage]
                                                                [
                                                                'text_pickdroplocation'],
                                                            style: GoogleFonts.notoSans(
                                                                fontSize: media
                                                                        .width *
                                                                    twelve,
                                                                color:
                                                                    hintColor),
                                                          )
                                                        : Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              SizedBox(
                                                                width: media
                                                                        .width *
                                                                    0.7,
                                                                child: Text(
                                                                  pickupAddressConfirmation,
                                                                  style: GoogleFonts
                                                                      .notoSans(
                                                                    fontSize: media
                                                                            .width *
                                                                        twelve,
                                                                    color:
                                                                        textColor,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                              ),
                                            ],
                                          )),
                                      SizedBox(
                                        height: media.width * 0.03,
                                      ),
                                      Button(
                                          onTap: () async {
                                            if (pickupAddressConfirmation !=
                                                '') {
                                              //remove in envato
                                              if (rideWithoutDestination ==
                                                      true &&
                                                  rentalRide == false) {
                                                if (addressList
                                                    .where((element) =>
                                                        element.type ==
                                                        'pickup')
                                                    .isEmpty) {
                                                  addressList.add(AddressList(
                                                      id: (addressList.length +
                                                              1)
                                                          .toString(),
                                                      type: 'pickup',
                                                      address:
                                                          pickupAddressConfirmation,
                                                      latlng: _center,
                                                      pickup: true));
                                                } else {
                                                  addressList
                                                          .firstWhere(
                                                              (element) =>
                                                                  element
                                                                      .type ==
                                                                  'pickup')
                                                          .address =
                                                      pickupAddressConfirmation;
                                                  addressList
                                                      .firstWhere((element) =>
                                                          element.type ==
                                                          'pickup')
                                                      .latlng = _center;
                                                  choosenTransportType = 0;
                                                  ismulitipleride = false;
                                                  Navigator.pushAndRemoveUntil(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              BookingConfirmation(
                                                                type: 2,
                                                              )),
                                                      (route) => false);
                                                }
                                              } else if ((rideWithoutDestination ==
                                                      false &&
                                                  rentalRide == true)) {
                                                if ((choosenTransportType ==
                                                        0 &&
                                                    widget.from == null)) {
                                                  if (addressList
                                                      .where((element) =>
                                                          element.type ==
                                                          'pickup')
                                                      .isEmpty) {
                                                    addressList.add(AddressList(
                                                        id: (addressList
                                                                    .length +
                                                                1)
                                                            .toString(),
                                                        type: 'pickup',
                                                        address:
                                                            pickupAddressConfirmation,
                                                        latlng: _center,
                                                        pickup: true));
                                                  } else {
                                                    addressList
                                                            .firstWhere(
                                                                (element) =>
                                                                    element
                                                                        .type ==
                                                                    'pickup')
                                                            .address =
                                                        pickupAddressConfirmation;
                                                    addressList
                                                        .firstWhere((element) =>
                                                            element.type ==
                                                            'pickup')
                                                        .latlng = _center;
                                                    setState(() {
                                                      if (rideWithoutDestination ==
                                                              true &&
                                                          rentalRide == false) {
                                                        ismulitipleride = false;
                                                        Navigator
                                                            .pushAndRemoveUntil(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder:
                                                                        (context) =>
                                                                            BookingConfirmation(
                                                                              type: 2,
                                                                            )),
                                                                (route) =>
                                                                    false);
                                                      } else {
                                                        ismulitipleride = false;
                                                        Navigator
                                                            .pushAndRemoveUntil(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder:
                                                                        (context) =>
                                                                            BookingConfirmation(
                                                                              type: 1,
                                                                            )),
                                                                (route) =>
                                                                    false);
                                                      }
                                                    });
                                                  }
                                                } else if ((choosenTransportType ==
                                                        1 &&
                                                    widget.from == null)) {
                                                  if (addressList
                                                      .where((element) =>
                                                          element.type ==
                                                          'pickup')
                                                      .isEmpty) {
                                                    addressList.add(AddressList(
                                                        id: (addressList
                                                                    .length +
                                                                1)
                                                            .toString(),
                                                        type: 'pickup',
                                                        address:
                                                            pickupAddressConfirmation,
                                                        latlng: _center,
                                                        pickup: true));
                                                  } else {
                                                    addressList
                                                            .firstWhere(
                                                                (element) =>
                                                                    element
                                                                        .type ==
                                                                    'pickup')
                                                            .address =
                                                        pickupAddressConfirmation;
                                                    addressList
                                                        .firstWhere((element) =>
                                                            element.type ==
                                                            'pickup')
                                                        .latlng = _center;
                                                    setState(() {
                                                      if (rideWithoutDestination ==
                                                              true &&
                                                          rentalRide == false) {
                                                        ismulitipleride = false;
                                                        Navigator
                                                            .pushAndRemoveUntil(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder:
                                                                        (context) =>
                                                                            BookingConfirmation(
                                                                              type: 2,
                                                                            )),
                                                                (route) =>
                                                                    false);
                                                      } else {
                                                        var val = rentalEta();
                                                        if (val == 'logout') {
                                                          navigateLogout();
                                                        }
                                                        dropConfirmed = true;
                                                        selectedGoodsId = '';
                                                        chooseGoodsTypes = true;
                                                        ismulitipleride = false;
                                                        Navigator
                                                            .pushAndRemoveUntil(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder:
                                                                        (context) =>
                                                                            BookingConfirmation(
                                                                              type: 1,
                                                                            )),
                                                                (route) =>
                                                                    false);
                                                      }
                                                    });
                                                  }
                                                }
                                              }
                                            }
                                          },
                                          text: languages[choosenLanguage]
                                              ['text_confirm'])
                                    ],
                                  ),
                                ),
                              ],
                            )),

                        //autofill address
                        Positioned(
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.fromLTRB(
                                  media.width * 0.05,
                                  MediaQuery.of(context).padding.top + 12.5,
                                  media.width * 0.05,
                                  0),
                              width: media.width * 1,
                              height: (addAutoFill.isNotEmpty)
                                  ? media.width * 1.3
                                  : null,
                              color: (addAutoFill.isEmpty)
                                  ? Colors.transparent
                                  : page,
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (_getDropDetails == false ||
                                              choosenTransportType == 0) {
                                            Navigator.pop(context);
                                          } else {
                                            setState(() {
                                              _getDropDetails = false;
                                            });
                                          }
                                        },
                                        child: Container(
                                          height: media.width * 0.1,
                                          width: media.width * 0.1,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    spreadRadius: 2,
                                                    blurRadius: 2)
                                              ],
                                              color: page),
                                          alignment: Alignment.center,
                                          child: Icon(Icons.arrow_back,
                                              color: textColor),
                                        ),
                                      ),
                                      Container(
                                        height: media.width * 0.1,
                                        width: media.width * 0.75,
                                        padding: EdgeInsets.fromLTRB(
                                            media.width * 0.05,
                                            0,
                                            media.width * 0.05,
                                            0),
                                        decoration: BoxDecoration(
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  spreadRadius: 2,
                                                  blurRadius: 2)
                                            ],
                                            color: page,
                                            borderRadius: BorderRadius.circular(
                                                media.width * 0.05)),
                                        child: TextField(
                                            controller: search,
                                            autofocus: (widget.from == 'add stop')
                                                ? true
                                                : false,
                                            decoration: InputDecoration(
                                                contentPadding:
                                                    (languageDirection == 'rtl')
                                                        ? EdgeInsets.only(
                                                            bottom:
                                                                media.width *
                                                                    0.03)
                                                        : EdgeInsets.only(
                                                            bottom: media.width *
                                                                0.042),
                                                border: InputBorder.none,
                                                hintText: languages[choosenLanguage][
                                                    'text_4lettersforautofill'],
                                                hintStyle: GoogleFonts.notoSans(
                                                    fontSize:
                                                        media.width * twelve,
                                                    color: textColor
                                                        .withOpacity(0.4))),
                                            style:
                                                GoogleFonts.notoSans(color: textColor),
                                            maxLines: 1,
                                            onChanged: (val) {
                                              if (val.isEmpty) {
                                                _sessionToken = null;
                                              }
                                              _debouncer.run(() {
                                                if (val.length >= 4) {
                                                  if (storedAutoAddress
                                                      .where((element) =>
                                                          element['description']
                                                              .toString()
                                                              .toLowerCase()
                                                              .contains(val
                                                                  .toLowerCase()))
                                                      .isNotEmpty) {
                                                    addAutoFill.removeWhere(
                                                        (element) =>
                                                            element['description']
                                                                .toString()
                                                                .toLowerCase()
                                                                .contains(val
                                                                    .toLowerCase()) ==
                                                            false);
                                                    storedAutoAddress
                                                        .where((element) => element[
                                                                'description']
                                                            .toString()
                                                            .toLowerCase()
                                                            .contains(val
                                                                .toLowerCase()))
                                                        .forEach((element) {
                                                      addAutoFill.add(element);
                                                    });
                                                    valueNotifierHome
                                                        .incrementNotifier();
                                                  } else {
                                                    _sessionToken ??=
                                                        const Uuid().v4();
                                                    getAutocomplete(
                                                        val,
                                                        _sessionToken,
                                                        _center.latitude,
                                                        _center.longitude);
                                                  }
                                                } else if (val.isEmpty) {
                                                  setState(() {
                                                    addAutoFill.clear();
                                                  });
                                                }
                                              });
                                            }),
                                      )
                                    ],
                                  ),
                                  SizedBox(
                                    height: media.width * 0.05,
                                  ),
                                  (addAutoFill.isNotEmpty)
                                      ? Container(
                                          height: media.height * 0.45,
                                          padding: EdgeInsets.all(
                                              media.width * 0.02),
                                          width: media.width * 0.9,
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      media.width * 0.05),
                                              color: page),
                                          child: SingleChildScrollView(
                                            child: Column(
                                              children: addAutoFill
                                                  .asMap()
                                                  .map((i, value) {
                                                    return MapEntry(
                                                        i,
                                                        (i < 7)
                                                            ? Material(
                                                                color: Colors
                                                                    .transparent,
                                                                child: InkWell(
                                                                  onTap:
                                                                      () async {
                                                                    // ignore: prefer_typing_uninitialized_variables
                                                                    var val;
                                                                    if (addAutoFill[i]
                                                                            [
                                                                            'lat'] ==
                                                                        '') {
                                                                      val = await geoCodingForLatLng(
                                                                          addAutoFill[i]
                                                                              [
                                                                              'place'],
                                                                          _sessionToken);
                                                                      _sessionToken =
                                                                          null;
                                                                    }

                                                                    setState(
                                                                        () {
                                                                      useMyAddress =
                                                                          true;
                                                                      _center = (addAutoFill[i]['lat'] == '' ||
                                                                              addAutoFill[i]['latitude'] ==
                                                                                  null)
                                                                          ? LatLng(
                                                                              double.parse(val['latitude']
                                                                                  .toString()),
                                                                              double.parse(val['longitude']
                                                                                  .toString()))
                                                                          : LatLng(
                                                                              double.parse(addAutoFill[i]['latitude'].toString()),
                                                                              double.parse(addAutoFill[i]['longitude'].toString()));
                                                                      pickupAddressConfirmation =
                                                                          addAutoFill[i]
                                                                              [
                                                                              'description'];
                                                                      if (mapType ==
                                                                          'google') {
                                                                        _controller?.moveCamera(CameraUpdate.newLatLngZoom(
                                                                            _center,
                                                                            14.0));
                                                                      } else {
                                                                        _fmController.move(
                                                                            fmlt.LatLng(_center.latitude,
                                                                                _center.longitude),
                                                                            14);
                                                                      }
                                                                    });
                                                                    FocusManager
                                                                        .instance
                                                                        .primaryFocus
                                                                        ?.unfocus();
                                                                    addAutoFill
                                                                        .clear();
                                                                    search.text =
                                                                        '';
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    padding: EdgeInsets.fromLTRB(
                                                                        0,
                                                                        media.width *
                                                                            0.04,
                                                                        0,
                                                                        media.width *
                                                                            0.04),
                                                                    child: Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      children: [
                                                                        Container(
                                                                          height:
                                                                              media.width * 0.1,
                                                                          width:
                                                                              media.width * 0.1,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            shape:
                                                                                BoxShape.circle,
                                                                            color:
                                                                                Colors.grey[200],
                                                                          ),
                                                                          child:
                                                                              const Icon(Icons.access_time),
                                                                        ),
                                                                        Container(
                                                                          alignment:
                                                                              Alignment.centerLeft,
                                                                          width:
                                                                              media.width * 0.7,
                                                                          child: Text(
                                                                              (addAutoFill[i]['description'] != null) ? addAutoFill[i]['description'] : addAutoFill[i]['display_name'],
                                                                              style: GoogleFonts.notoSans(
                                                                                fontSize: media.width * twelve,
                                                                                color: textColor,
                                                                              ),
                                                                              maxLines: 2),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              )
                                                            : Container());
                                                  })
                                                  .values
                                                  .toList(),
                                            ),
                                          ),
                                        )
                                      : Container()
                                ],
                              ),
                            )),

                        //fav address
                        (favAddressAdd == true)
                            ? Positioned(
                                top: 0,
                                child: Container(
                                  height: media.height * 1,
                                  width: media.width * 1,
                                  color: Colors.transparent.withOpacity(0.6),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: media.width * 0.9,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              height: media.width * 0.1,
                                              width: media.width * 0.1,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: page),
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    favName = '';
                                                    favAddressAdd = false;
                                                  });
                                                },
                                                child: const Icon(
                                                    Icons.cancel_outlined),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height: media.width * 0.05,
                                      ),
                                      Container(
                                        padding:
                                            EdgeInsets.all(media.width * 0.05),
                                        width: media.width * 0.9,
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            color: page),
                                        child: Column(
                                          children: [
                                            Text(
                                              languages[choosenLanguage]
                                                  ['text_saveaddressas'],
                                              style: GoogleFonts.notoSans(
                                                  fontSize:
                                                      media.width * sixteen,
                                                  color: textColor,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            SizedBox(
                                              height: media.width * 0.025,
                                            ),
                                            Text(
                                              favSelectedAddress,
                                              style: GoogleFonts.notoSans(
                                                  fontSize:
                                                      media.width * twelve,
                                                  color: textColor),
                                            ),
                                            SizedBox(
                                              height: media.width * 0.025,
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                    setState(() {
                                                      favName = 'Home';
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.all(
                                                        media.width * 0.01),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          height: media.height *
                                                              0.05,
                                                          width: media.width *
                                                              0.05,
                                                          decoration: BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .black,
                                                                  width: 1.2)),
                                                          alignment:
                                                              Alignment.center,
                                                          child: (favName ==
                                                                  'Home')
                                                              ? Container(
                                                                  height: media
                                                                          .width *
                                                                      0.03,
                                                                  width: media
                                                                          .width *
                                                                      0.03,
                                                                  decoration:
                                                                      const BoxDecoration(
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    color: Colors
                                                                        .black,
                                                                  ),
                                                                )
                                                              : Container(),
                                                        ),
                                                        SizedBox(
                                                          width: media.width *
                                                              0.01,
                                                        ),
                                                        Text(languages[
                                                                choosenLanguage]
                                                            ['text_home'])
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () {
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                    setState(() {
                                                      favName = 'Work';
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.all(
                                                        media.width * 0.01),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          height: media.height *
                                                              0.05,
                                                          width: media.width *
                                                              0.05,
                                                          decoration: BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .black,
                                                                  width: 1.2)),
                                                          alignment:
                                                              Alignment.center,
                                                          child: (favName ==
                                                                  'Work')
                                                              ? Container(
                                                                  height: media
                                                                          .width *
                                                                      0.03,
                                                                  width: media
                                                                          .width *
                                                                      0.03,
                                                                  decoration:
                                                                      const BoxDecoration(
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    color: Colors
                                                                        .black,
                                                                  ),
                                                                )
                                                              : Container(),
                                                        ),
                                                        SizedBox(
                                                          width: media.width *
                                                              0.01,
                                                        ),
                                                        Text(languages[
                                                                choosenLanguage]
                                                            ['text_work'])
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () {
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                    setState(() {
                                                      favName = 'Others';
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.all(
                                                        media.width * 0.01),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          height: media.height *
                                                              0.05,
                                                          width: media.width *
                                                              0.05,
                                                          decoration: BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .black,
                                                                  width: 1.2)),
                                                          alignment:
                                                              Alignment.center,
                                                          child: (favName ==
                                                                  'Others')
                                                              ? Container(
                                                                  height: media
                                                                          .width *
                                                                      0.03,
                                                                  width: media
                                                                          .width *
                                                                      0.03,
                                                                  decoration:
                                                                      const BoxDecoration(
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    color: Colors
                                                                        .black,
                                                                  ),
                                                                )
                                                              : Container(),
                                                        ),
                                                        SizedBox(
                                                          width: media.width *
                                                              0.01,
                                                        ),
                                                        Text(languages[
                                                                choosenLanguage]
                                                            ['text_others'])
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            (favName == 'Others')
                                                ? Container(
                                                    padding: EdgeInsets.all(
                                                        media.width * 0.025),
                                                    decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                            color: borderLines,
                                                            width: 1.2)),
                                                    child: TextField(
                                                      decoration: InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                          hintText: languages[
                                                                  choosenLanguage]
                                                              [
                                                              'text_enterfavname'],
                                                          hintStyle: GoogleFonts
                                                              .notoSans(
                                                                  fontSize: media
                                                                          .width *
                                                                      twelve,
                                                                  color:
                                                                      hintColor)),
                                                      maxLines: 1,
                                                      onChanged: (val) {
                                                        setState(() {
                                                          favNameText = val;
                                                        });
                                                      },
                                                    ),
                                                  )
                                                : Container(),
                                            SizedBox(
                                              height: media.width * 0.05,
                                            ),
                                            Button(
                                                onTap: () async {
                                                  if (favName == 'Others' &&
                                                      favNameText != '') {
                                                    setState(() {
                                                      _isLoading = true;
                                                    });
                                                    var val =
                                                        await addFavLocation(
                                                            favLat,
                                                            favLng,
                                                            favSelectedAddress,
                                                            favNameText);
                                                    setState(() {
                                                      _isLoading = false;
                                                      if (val == true) {
                                                        favLat = '';
                                                        favLng = '';
                                                        favSelectedAddress = '';
                                                        favNameText = '';
                                                        favName = 'Home';
                                                        favAddressAdd = false;
                                                      } else if (val ==
                                                          'logout') {
                                                        navigateLogout();
                                                      }
                                                    });
                                                  } else if (favName ==
                                                          'Home' ||
                                                      favName == 'Work') {
                                                    setState(() {
                                                      _isLoading = true;
                                                    });
                                                    var val =
                                                        await addFavLocation(
                                                            favLat,
                                                            favLng,
                                                            favSelectedAddress,
                                                            favName);
                                                    setState(() {
                                                      _isLoading = false;
                                                      if (val == true) {
                                                        favLat = '';
                                                        favLng = '';
                                                        favSelectedAddress = '';
                                                        favNameText = '';
                                                        favName = 'Home';
                                                        favAddressAdd = false;
                                                      } else if (val ==
                                                          'logout') {
                                                        navigateLogout();
                                                      }
                                                    });
                                                  }
                                                },
                                                text: languages[choosenLanguage]
                                                    ['text_confirm'])
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ))
                            : Container(),

                        (_locationDenied == true)
                            ? Positioned(
                                child: Container(
                                height: media.height * 1,
                                width: media.width * 1,
                                color: Colors.transparent.withOpacity(0.6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: media.width * 0.9,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                _locationDenied = false;
                                              });
                                            },
                                            child: Container(
                                              height: media.height * 0.05,
                                              width: media.height * 0.05,
                                              decoration: BoxDecoration(
                                                color: page,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.cancel,
                                                  color: buttonColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: media.width * 0.025),
                                    Container(
                                      padding:
                                          EdgeInsets.all(media.width * 0.05),
                                      width: media.width * 0.9,
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: page,
                                          boxShadow: [
                                            BoxShadow(
                                                blurRadius: 2.0,
                                                spreadRadius: 2.0,
                                                color: Colors.black
                                                    .withOpacity(0.2))
                                          ]),
                                      child: Column(
                                        children: [
                                          SizedBox(
                                              width: media.width * 0.8,
                                              child: Text(
                                                languages[choosenLanguage]
                                                    ['text_open_loc_settings'],
                                                style: GoogleFonts.notoSans(
                                                    fontSize:
                                                        media.width * sixteen,
                                                    color: textColor,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              )),
                                          SizedBox(height: media.width * 0.05),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              InkWell(
                                                  onTap: () async {
                                                    await perm
                                                        .openAppSettings();
                                                  },
                                                  child: Text(
                                                    languages[choosenLanguage]
                                                        ['text_open_settings'],
                                                    style: GoogleFonts.notoSans(
                                                        fontSize: media.width *
                                                            sixteen,
                                                        color: buttonColor,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  )),
                                              InkWell(
                                                  onTap: () async {
                                                    setState(() {
                                                      _locationDenied = false;
                                                      _isLoading = true;
                                                    });

                                                    getLocs();
                                                  },
                                                  child: Text(
                                                    languages[choosenLanguage]
                                                        ['text_done'],
                                                    style: GoogleFonts.notoSans(
                                                        fontSize: media.width *
                                                            sixteen,
                                                        color: buttonColor,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ))
                                            ],
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ))
                            : Container(),

                        //loader
                        (_isLoading == true)
                            ? const Positioned(child: Loading())
                            : Container(),
                        //no internet
                        (internet == false)
                            ? Positioned(
                                top: 0,
                                child: NoInternet(
                                  onTap: () {
                                    setState(() {
                                      internetTrue();
                                    });
                                  },
                                ))
                            : Container()
                      ],
                    ),
                  ),
                );
              }),
        ),
      ),
    );
  }
}
