Part of the [ad\_hoc\_ident](https://pub.dev/packages/ad_hoc_ident) framework.
Provides basic camera input capabilities based on the [camera](https://pub.dev/packages/camera) plugin.

> The [camerax](https://pub.dev/packages/camera_android_camerax) implementation of 
> [camera](https://pub.dev/packages/camera) cannot produce nv21 format images as required by 
> [Google Text Recognition](https://pub.dev/packages/google_mlkit_text_recognition). 
> Use the [camera\_android](https://pub.dev/packages/camera_android) implementation instead as 
> described on the package's page.

> Some features are currently only supported on Android.

> Using NFC and the camera at the same time can lead to crashes.
> Disable the camera before presenting a NFC tag.

## Features
The package consists of three domain packages. Each is provided with some implementation packages.
* Provides a camera preview that converts the video stream to OcrImages, ready for processing.

## Getting started

Add the main domain package to your app's pubspec.yaml file and
add the packages of the features you require for your app.

## Usage

Make yourself familiar with the example app in the
[ad\_hoc\_ident](https://pub.dev/packages/ad_hoc_ident) package,
as it provides a good overview on how to combine the different packages.
Otherwise pick and match the features that suite you.
All features implemented out of the box have their interfaces defined in the respective
domain package, so you can easily create and integrate your own implementations.

## Additional information

If you use this package and implement your own features or extend the existing ones,
consider creating a pull request. This project was created for university, but if it is useful
to other developers I might consider supporting further development.

Please be aware that reading MRZ documents or NFC tags of other persons might be restricted by
local privacy laws.
