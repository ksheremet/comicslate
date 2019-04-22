import 'dart:math';
import 'dart:typed_data';

import 'package:comicslate/models/comic_strip.dart';
import 'package:comicslate/view/helpers/comic_page_view_model_iw.dart';
import 'package:comicslate/view/helpers/comicslate_client.dart';
import 'package:comicslate/view_model/comic_page_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_advanced_networkimage/zoomable.dart';
import 'package:share/share.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ComicPage extends StatelessWidget {
  final pageTextController = TextEditingController();

  @override
  Widget build(BuildContext context) => Scaffold(
        // When keyboard appears it is breaks layout if it is not scrollable.
        // This property helps to appear the keyboard above the screen.
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title:
              Text(ComicPageViewModelWidget.of(context).viewModel.comic.name),
          actions: <Widget>[
            MaterialButton(
              padding: const EdgeInsets.all(8),
              child: const Text(
                'go to',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                pageTextController.text = ComicPageViewModelWidget.of(context)
                    .viewModel
                    .currentStripId;
                final allStrips = ComicPageViewModelWidget.of(context)
                    .viewModel
                    .stripIds
                    .length;
                final onGoToPage =
                    ComicPageViewModelWidget.of(context).viewModel.onGoToPage;
                showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) =>
                        _showGoToPageDialog(context, allStrips, onGoToPage));
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Share.share(ComicPageViewModelWidget.of(context)
                    .viewModel
                    .currentStrip
                    .shareUrl
                    .toString());
              },
            ),
            /*IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                showModalBottomSheet(
                    context: context, builder: (context) => _buildComicInfo());
              },
            )*/
          ],
        ),
        // Get a list of stripsId
        body: FutureBuilder<Iterable<String>>(
          future: ComicslateClientWidget.of(context)
              .client
              .getStoryStripsList(
                  ComicPageViewModelWidget.of(context).viewModel.comic)
              .first,
          builder: (context, stripListSnapshot) {
            if (stripListSnapshot.hasData) {
              // Load image
              ComicPageViewModelWidget.of(context).viewModel.stripIds =
                  stripListSnapshot.data.toList();
              return StripPage(
                viewModel: ComicPageViewModelWidget.of(context).viewModel,
              );
            } else {
              return Center(child: const CircularProgressIndicator());
            }
          },
        ),
      );

  Widget _showGoToPageDialog(
          BuildContext context, int allStrips, Sink onGoToPage) =>
      AlertDialog(
        title: const Text('Перейти на страницу'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 100,
              height: 60,
              child: TextField(
                controller: pageTextController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (page) {
                  onGoToPage.add(page);
                  Navigator.of(context).pop();
                },
              ),
            ),
            Text(' / $allStrips'),
          ],
        ),
        actions: <Widget>[
          FlatButton(
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          FlatButton(
            child: const Text(
              'Перейти',
              style: TextStyle(color: Colors.teal),
            ),
            onPressed: () {
              onGoToPage.add(pageTextController.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      );

  /*Widget _buildComicInfo() => Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Автор:  ${_viewModel.currentStrip.author}',
              style: TextStyle(fontSize: 20),
            ),
            Container(
              height: 10,
            ),
            Text(
              'Дата последнего изменения:  '
              '${DateFormat.yMMMd().add_jm()
              .format(_viewModel.currentStrip.lastModified)}',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      );*/
}

class StripPage extends StatefulWidget {
  final ComicPageViewModel viewModel;

  StripPage({@required this.viewModel}) : assert(viewModel != null);

  @override
  _StripPageState createState() => _StripPageState();
}

class _StripPageState extends State<StripPage> {
  PageController _controller;
  bool _isOrientationSetup = false;
  Future<int> _lastSeenStrip;

  @override
  void initState() {
    widget.viewModel.doGoToPage.listen((page) {
      _controller.jumpToPage(page);
    });

    _lastSeenStrip = widget.viewModel.getLastSeenPage();
    super.initState();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
        future: _lastSeenStrip,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _controller = PageController(initialPage: snapshot.data);
            return PageView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _controller,
              itemCount: widget.viewModel.stripIds.length,
              itemBuilder: (context, i) => FutureBuilder<ComicStrip>(
                  future: ComicslateClientWidget.of(context)
                      .client
                      .getStrip(
                        widget.viewModel.comic,
                        widget.viewModel.stripIds.elementAt(i),
                        prefetch: widget.viewModel.stripIds.sublist(
                          max(0, i - 2),
                          min(widget.viewModel.stripIds.length - 1, i + 5),
                        ),
                      )
                      .first,
                  builder: (context, stripSnapshot) {
                    if (stripSnapshot.hasData) {
                      if (stripSnapshot.data.imageBytes == null) {
                        return WebView(
                          initialUrl: stripSnapshot.data.displayUrl.toString(),
                          javascriptMode: JavascriptMode.unrestricted,
                        );
                      } else {
                        if (!_isOrientationSetup) {
                          setUpOrientation(stripSnapshot.data.imageBytes);
                        }
                        widget.viewModel.currentStrip = stripSnapshot.data;
                        widget.viewModel.currentStripId =
                            widget.viewModel.stripIds.elementAt(i);
                        // TODO(ksheremet): Zoomable widget doesn't work
                        //  in Column
                        return StripImage(
                          viewModel: widget.viewModel,
                        );
                      }
                    } else {
                      return Center(child: const CircularProgressIndicator());
                    }
                  }),
              onPageChanged: (index) {
                widget.viewModel.setLastSeenPage(index);
              },
            );
          } else {
            return const CircularProgressIndicator();
          }
        },
      );

  // TODO(ksheremet): Consider more elegant solution, doesnt' work on iOS
  void setUpOrientation(Uint8List imageBytes) {
    final image = MemoryImage(imageBytes);
    image
        .resolve(createLocalImageConfiguration(context))
        .addListener((imageInfo, error) {
      _isOrientationSetup = true;
      if (imageInfo.image.width > imageInfo.image.height) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ]);
      } else {
        SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      }
    });
  }

  @override
  void dispose() {
    // When we leave the screen enable screen rotation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
}

class StripImage extends StatelessWidget {
  final ComicPageViewModel viewModel;
  StripImage({@required this.viewModel}) : assert(viewModel != null);

  @override
  Widget build(BuildContext context) {
    var aboutStrip =
        '${viewModel.currentStripId} / ${viewModel.stripIds.length}  ';
    if (viewModel.currentStrip.title != null) {
      aboutStrip = aboutStrip + viewModel.currentStrip.title;
    }
    return ZoomableWidget(
        enableRotate: false,
        maxScale: 3,
        zoomSteps: 2,
        multiFingersPan: true,
        singleFingerPan: false,
        minScale: 1,
        child: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(aboutStrip),
          ),
          Expanded(child: Image.memory(viewModel.currentStrip.imageBytes)),
        ]));
  }
}
