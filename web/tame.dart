import "dart:async";
import "dart:html";

import "package:image_whisperer/image_whisperer.dart";

Future<CanvasElement> showIn(String selector, BaseImage image) async {
  Element parent = document.querySelector(selector);
  parent.children.clear();
  CanvasElement canvas = (await image.toCanvasImage()).canvas;
  parent.append(canvas);
  return canvas;
}

void download(String filename, Blob blob) {
  String url;
  try {
    url = Url.createObjectUrl(blob);
    AnchorElement a = new AnchorElement();
    a.download = filename;
    a.href = url;
    a.click();
  } finally {
    if (url != null) Url.revokeObjectUrl(url);
  }
}

typedef void PipelineModifier(ImageProcessingPipeline pipeline, String value);

Map<String, PipelineModifier> modifiers = {
  "maxWidth": (pipeline, value) => pipeline.maxWidth = int.parse(value, onError: (_) => null),
  "maxHeight": (pipeline, value) => pipeline.maxHeight = int.parse(value, onError: (_) => null),
  "maxMegapixels": (pipeline, value) {
    double val = double.parse(value, (_) => null);
    if (val == null) {
      pipeline.maxPixels = val;
    } else {
      pipeline.maxPixels = val * 1000000;
    }
  },
};

void main() {
  Element spinner = document.querySelector("#spinner");
  int angle = 0;
  new Timer.periodic(new Duration(milliseconds: 16), (Timer timer) {
    angle += 2;
    angle %= 360;
    spinner.style.transform = "rotate(${angle}deg)";
  });
  ImageProcessingPipeline pipeline = new ImageProcessingPipeline();
  pipeline.requireBlob("image/jpeg", quality: 75);
  pipeline.maxPixels = 4096;
  ButtonElement button = querySelector("button");
  button.onClick.listen((Event event) {
    button.disabled = true;
    for (String key in modifiers.keys) {
      PipelineModifier modifier = modifiers[key];
      InputElement input = querySelector("input[name=$key]");
      modifier(pipeline, input.value);
    }
    bool needFile = event is MouseEvent && (event.shiftKey || event.altKey);
    FileUploadInputElement input = querySelector("input[type=file]");
    File file = input.files.first;
    BlobImage image = new BlobImage(file, name: file.name);
    showIn("#naive", image).then((CanvasElement canvas) {
      canvas.style.maxWidth = "64px";
      canvas.style.maxHeight = "64px";
    });
    pipeline.process(image).then((BaseImage result) {
      showIn("#tamed", result);
      BlobImage blobImage = result;
      print(blobImage.blob.type);
      if (needFile) download(blobImage.name, blobImage.blob);
    }).whenComplete(() {
      button.disabled = false;
    });
  });
}
