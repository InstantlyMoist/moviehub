import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum Options { addToList, watchTrailer }

// ignore: must_be_immutable
class MovieSettings extends StatefulWidget {
  Function(BuildContext context, String selection) selectionCallback;

  MovieSettings({this.selectionCallback});

  @override
  _MovieSettingsState createState() => _MovieSettingsState();
}

class _MovieSettingsState extends State<MovieSettings> {
  Options _selection;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(right: 10),
      width: 35,
      height: 100,
      child: Align(
        alignment: Alignment.topRight,
        child: PopupMenuButton<Options>(
          onSelected: (Options result) {
            widget.selectionCallback(context, result.toString());
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<Options>>[
            const PopupMenuItem<Options>(
              value: Options.addToList,
              child: ListTile(
                leading: IconButton(
                  padding: EdgeInsets.all(0.0),
                  icon: Icon(
                    Icons.playlist_add,
                    color: Color(0xFF3e3e3e),
                    size: 20,
                  ),
                ),
                title: Text("Add move to a list"),
              ),
            ),
            const PopupMenuItem<Options>(
              value: Options.watchTrailer,
              child: ListTile(
                leading: IconButton(
                  padding: EdgeInsets.all(0.0),
                  icon: Icon(
                    Icons.movie,
                    color: Color(0xFF3e3e3e),
                    size: 20,
                  ),
                ),
                title: Text("Watch the trailer"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}