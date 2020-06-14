function [ newimg ] =extract_man_transition( img )

img = medfilt2(img , [7,5]);
edge_img = edge (img , 'canny');


% edge_img = bwareaopen(edge_img, 30 );

% edge_img = imdilate(edge_img , ones(2,2));
newimg=edge_img;
end


