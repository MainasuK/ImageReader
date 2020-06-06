# ImageReader

macOS App for demonstrate image analysis tool like Vision.framework.

## Feature

### Vision.framework
- [x] Text Recognization
- [ ] Object Detecting
- [ ] Face Detecting
- [ ] Feature Print
- [x] Saliency
  - [x] Attention Based
  - [x] Objectness Based

### CoreImage.framework
- [ ] Object Detecting
- [ ] Face Detecting

### OpenCV
- [x] SURF Feature Detection
- [x] FLANN based Image Matching

### Tesseract
- [x] Text Recognization


## Setup
ImageReader using multiple framework to operate image. Please read the reference dependencies README to setup building environment.

- [SwiftTesseract](https://github.com/MainasuK/SwiftTesseract#setup): Setup Tesseract installation.

## Release
You can download notarized app release from [here](https://github.com/MainasuK/ImageReader/releases).


## Demo
![Text Recognize](./Press/snapshot.png)

![Image Saliency](./Press/snapshot-2.png)
> Photo from Unsplash @zis_view 

![Image Matching](./Press/snapshot-3.png)
> Photo by Mak on Unsplash