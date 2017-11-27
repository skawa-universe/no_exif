import "dart:html";
import "dart:async";

abstract class FileDropListener {
  /// Asks the drop listener whether the file with the mime type
  /// should be accepted.
  bool isMimeTypeAccepted(String mimeType);

  /// Tells the drop listener to set the drop target to an
  /// accepting state.
  void set accepting(bool value);

  /// Called when the files are actually dropped.
  void acceptBlobs(List<Blob> files);
}

class Dropper {
  Dropper(this._listener, this._element) {
    _subscriptions = [];
    reattach();
  }

  void detach() {
    _subscriptions.forEach((StreamSubscription sub) {
      sub.cancel();
    });
    _subscriptions = [];
  }

  void reattach() {
    if (_subscriptions.isEmpty) {
      _subscriptions.addAll([
        _element.onDragOver.listen(_dragOver),
        _element.onDrop.listen(_drop),
        _element.onDragEnter.listen(_dragEnter),
        _element.onDragLeave.listen(_dragLeave),
        _element.onPaste.listen(_paste),
      ]);
    }
  }

  void _paste(ClipboardEvent event) {
    DataTransferItemList items = event.clipboardData.items;
    List<Blob> blobs = [];
    for (DataTransferItem item in listOfDataTransferItems(items)) {
      if (item.kind == "file" && _listener.isMimeTypeAccepted(item.type)) {
        Blob blob = item.getAsFile();
        if (blob is File) window.console.log("Found a file: ${blob.name}");
        blobs.add(blob);
      } else {
        window.console.log("Don't know what to do with this: "
            "${item.kind}, ${item.type}");
      }
    }
    if (blobs.isNotEmpty) {
      _listener.acceptBlobs(
          blobs.where((Blob f) => _listener.isMimeTypeAccepted(f.type)).toList(growable: false));
    }
  }

  void _dragOver(MouseEvent e) {
    e.stopPropagation();
    e.preventDefault();
    var hasAny = _isAnyAcceptable(e.dataTransfer);
    e.dataTransfer.dropEffect = hasAny ? "copy" : "none";
    _listener.accepting = hasAny;
  }

  void _drop(MouseEvent e) {
    e.stopPropagation();
    e.preventDefault();
    List<File> files = e.dataTransfer.files;
    _listener.acceptBlobs(
        files.where((File f) => _listener.isMimeTypeAccepted(f.type)).toList(growable: false));
    _listener.accepting = false;
  }

  void _dragEnter(MouseEvent e) {
    if (_isAnyAcceptable(e.dataTransfer)) _listener.accepting = true;
  }

  void _dragLeave(MouseEvent e) {
    _listener.accepting = false;
  }

  List<DataTransferItem> listOfDataTransferItems(DataTransferItemList list) {
    if (list == null) return [];
    return new List<DataTransferItem>.generate(list.length, (i) => list[i]);
  }

  bool _isAnyAcceptable(DataTransfer dataTransfer) {
    List<File> files = dataTransfer.files ?? [];
    for (File file in files) {
      if (_listener.isMimeTypeAccepted(file.type)) return true;
    }
    List<DataTransferItem> items = listOfDataTransferItems(dataTransfer.items);
    for (DataTransferItem item in items) {
      if (_listener.isMimeTypeAccepted(item.type)) return true;
    }
    return false;
  }

  final Element _element;
  final FileDropListener _listener;
  List<StreamSubscription> _subscriptions;
}
