import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TimerBlock extends StatelessWidget {
	final String time;
  final String state;

	const TimerBlock({
		required this.time,
		required this.state,
		super.key,
	});

  int getTimeDifference(String time){
    DateTime dttime = DateTime.parse(time);
    DateTime dtnow = DateTime.now();

    Duration diff = dttime.difference(dtnow);

    return diff.inMinutes;
  }
  String getTime(String time){
    DateTime dttime = DateTime.parse(time);

    String dthour = dttime.hour < 10 ? "0" + dttime.hour.toString() : dttime.hour.toString();
    String dtminute = dttime.minute < 10 ? "0" + dttime.minute.toString() : dttime.minute.toString();

    return '${dthour}h${dtminute}';
  }

  TextStyle getStyleByState(state, context) {
    if (state == "onTime") {
      return TextStyle( color: getColorByState(state, context), fontWeight: FontWeight.w700, fontFamily: 'Segoe Ui' );

    } else if (state == "noReport") {
      return TextStyle( color: getColorByState(state, context),   fontWeight: FontWeight.w700,   fontFamily: 'Segoe Ui');

    }
    return TextStyle( color: getColorByState(state, context),  fontWeight: FontWeight.w700,  fontFamily: 'Segoe Ui');
  }

  Color getColorByState(state, context) {
    if (state == "onTime") {
      return Theme.of(context).colorScheme.secondary;
    } else if (state == "noReport") {
      return Color(0xffa9a9a9);
    }
    return Color(0xfff68f53);
    
  }


	@override
	Widget build(BuildContext context) => 

  getTimeDifference(time) >= 0 && time != "" 
    ? getTimeDifference(time) < 99
      ? Container(
          clipBehavior: Clip.hardEdge,
          padding: state == "noReport" ? EdgeInsets.only(left:10.0, top:5.0, right:10.0,bottom:5.0) : EdgeInsets.only(left:10.0, top:5.0, right:0.0,bottom:5.0),
          margin: EdgeInsets.only(left:0.0, top:5.0, right:10.0,bottom:5.0),
          constraints: BoxConstraints( minWidth: 60 ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                spreadRadius: 3,
                blurRadius: 5,
                offset: const Offset(0, 2),
              )
            ]
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                child: Text('${getTimeDifference(time).toString()} min',
                    style: getStyleByState(state, context),
                    textAlign: TextAlign.center,
                  ),
              ),
              state == "noReport"
              ? Text('')
              : SvgPicture.asset('assets/sign_top.svg',
                  color: getColorByState(state, context),
                  height: 15
                )
            ],
          ),
        )
      : Container(
          padding: EdgeInsets.only(left:10.0, top:5.0,right:10.0,bottom:5.0),
          margin: EdgeInsets.only(left:0.0, top:5.0,right:10.0,bottom:5.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                spreadRadius: 3,
                blurRadius: 5,
                offset: const Offset(0, 2),
              )
            ]
          ),
          child: Text(
            getTime(time),
            style: getStyleByState(state, context),
            textAlign: TextAlign.center,
          ),
        )
    : const Text('');
}

