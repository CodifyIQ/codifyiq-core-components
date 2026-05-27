import 'dart:io';

import 'package:flutter/widgets.dart';

/// Returns an [ImageProvider] backed by a file on the device's file system.
///
/// Non-web implementation — uses [FileImage] with a `dart:io` [File].
ImageProvider fileImageProvider(String path) => FileImage(File(path));
