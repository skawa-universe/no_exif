import "dart:async";
import "dart:html";

import "package:pool/pool.dart";
import "package:image_whisperer/image_whisperer.dart";
import "package:no_exif/dropper.dart";
import "package:stack_trace/stack_trace.dart";

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
  "maxWidth": (pipeline, value) => pipeline.maxWidth = int.tryParse(value),
  "maxHeight": (pipeline, value) => pipeline.maxHeight = int.tryParse(value),
  "maxMegapixels": (pipeline, value) {
    double val = double.tryParse(value);
    if (val == null) {
      pipeline.maxPixels = val.toInt();
    } else {
      pipeline.maxPixels = (val * 1000000).toInt();
    }
  },
};

/// One image at a time
Pool _processes = new Pool(1);

Future<Null> waitForSlot<T>(Pool pool, FutureOr<T> callback()) async {
  PoolResource resource = await pool.request();
  // ignore: unawaited_futures
  new Future<T>.sync(callback).whenComplete(resource.release);
}

Future<Null> processFile(File file, ImageProcessingPipeline pipeline, {bool needFile}) async {
  await waitForSlot(_processes, () async {
    BlobImage image = new BlobImage(file, name: file.name);
    showIn("#naive", image).then((CanvasElement canvas) {
      canvas.style.maxWidth = "64px";
      canvas.style.maxHeight = "64px";
    });
    await pipeline.process(image).then((BaseImage result) {
      showIn("#tamed", result);
      BlobImage blobImage = result;
      print(blobImage.blob.type);
      if (needFile ?? false) download(blobImage.name, blobImage.blob);
    });
  });
}

class FileDropAdapter implements FileDropListener {
  FileDropAdapter(this.dropArea, this.pipeline);

  @override
  void acceptBlobs(List<Blob> files) {
    files.forEach((Blob file) => processFile(file as File, pipeline));
  }

  @override
  set accepting(bool value) {
    dropArea.classes.toggle("dropping", value);
  }

  @override
  bool isMimeTypeAccepted(String mimeType) => mimeType?.startsWith("image/") ?? false;

  final Element dropArea;
  final ImageProcessingPipeline pipeline;
}

void bindAll() {
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
    processFile(file, pipeline, needFile: needFile).whenComplete(() {
      button.disabled = false;
    });
  });
  new Dropper(new FileDropAdapter(document.body, pipeline), document.body);
}

void main() {
  Chain.capture(bindAll, onError: (e, chain) {
    print("Error: $e\n$chain");
  });
}
