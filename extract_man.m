function [ output ] = extract_man( img )

redChannel = img(:,:,1); % Red channel
greenChannel = img(:,:,2); % Green channel
blueChannel = img(:,:,3); % Blue channel
%newBlue = getNewBlue(redChannel,greenChannel,blueChannel);
redChannel = extract_man_transition(redChannel);
blueChannel = extract_man_transition(blueChannel);
greenChannel = extract_man_transition(greenChannel);
newimg = redChannel + blueChannel + greenChannel;
% newimg = imdilate(newimg , ones(4,4));
newimg= imfill(newimg,'holes');
%newimg= bwareafilt(logical(newimg),1);

output = newimg;
% output = extractobject(img , newimg);

end

