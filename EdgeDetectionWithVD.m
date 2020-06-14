function [ newimg ] = EdgeDetectionWithVD(img)

 [w,h] = size(img);
frmActivePixels = w;
frmActiveLines = h;
frmOrig = img ;
frmInput=frmOrig(1:frmActiveLines,1:frmActivePixels); 
figure
imshow(frmInput)
title 'Input Image'
frm2pix = visionhdl.FrameToPixels(...
      'NumComponents',1,...
      'VideoFormat','custom',...
      'ActivePixelsPerLine',frmActivePixels,...
      'ActiveVideoLines',frmActiveLines,...
      'TotalPixelsPerLine',frmActivePixels,...
      'TotalVideoLines',frmActiveLines,...
      'StartingActiveLine',6,...
      'FrontPorch',5);
  

edgeDetectSobel = visionhdl.EdgeDetector();
[pixIn,ctrlIn] = step(frm2pix,frmInput);

[~,~,numPixelsPerFrame] = getparamfromfrm2pix(frm2pix);
ctrlOut = repmat(pixelcontrolstruct,numPixelsPerFrame,1);
edgeOut = false(numPixelsPerFrame,1);
for p = 1:numPixelsPerFrame
   [edgeOut(p),ctrlOut(p)] = step(edgeDetectSobel,pixIn(p),ctrlIn(p));
end
pix2frm = visionhdl.PixelsToFrame(...
      'NumComponents',1,...
      'VideoFormat','custom',...
      'ActivePixelsPerLine',frmActivePixels,...
      'ActiveVideoLines',frmActiveLines);

[frmOutput,frmValid] = step(pix2frm,edgeOut,ctrlOut);
if frmValid
    figure
    imshow(frmOutput)
    title 'Output Image'
end
newimg = frmOutput;
end

