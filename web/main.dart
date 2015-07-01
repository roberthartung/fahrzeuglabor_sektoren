// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:async';
import 'dart:math';

VideoElement video = document.querySelector('#video');
CanvasElement canvas = document.querySelector('#canvas');
CanvasRenderingContext2D ctx = canvas.getContext('2d');
ButtonElement createSectorButton = document.querySelector('#btn-create-sector');
ButtonElement playButton = document.querySelector('#btn-play');
TableSectionElement sectorsTable = document.querySelector('#sectors');
ButtonElement loadWebcamButton = document.querySelector('#btn-load-webcam');
Point newSectorBegin;
Point newSectorEnd;
List<Sector> sectors = [];
String notifyText = null;
num notifyTextSize;

class Color {
  final num r, g, b;
  Color(this.r, this.g, this.b);
  
  String toString() => 'Color(${r.toStringAsFixed(3)},${g.toStringAsFixed(3)},${b.toStringAsFixed(3)})';
}

class Sector {
  final Rectangle r;
  
  TableRowElement tr;
  
  Color neutral;
  
  double startTime = null;
  
  double roundTime = null;
  
  bool requestNeutral = false;
  
  SpanElement neutralLabel = new SpanElement();
  
  Sector(this.r) {
    tr = new TableRowElement();
    sectorsTable.append(tr);
    tr.append(new TableCellElement() ..text = '$r');
    tr.append(new TableCellElement() ..append(neutralLabel));
    tr.append(new TableCellElement() ..append(new ButtonElement()
      ..text = 'Get average color'
      ..onClick.listen((MouseEvent ev) {
        requestNeutral = true;
      }))
    );
  }
  
  ImageData getData() {
    return ctx.getImageData(r.left, r.top, r.width, r.height);
  }
  
  Color getAverageColor() {
    ImageData data = getData();
    int total = data.width * data.height;
    num r = 0, g = 0, b = 0;
    for(int i=0; i<total; i+=4) {
      r += data.data[i];
      g += data.data[i+1];
      b += data.data[i+2];
    }
    int numPixels = total~/4;
    return new Color(r/numPixels,g/numPixels,b/numPixels);
  }
}

const int SECTOR_THRESHOLD = 15;

void notifyNewTime(num time) {
  notifyText = time.toStringAsFixed(3);
  notifyTextSize = 100;
}

void render(num time) {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(video, 0, 0);
  
  sectors.forEach((Sector s) {
    if(s.requestNeutral) {
      s.requestNeutral = false;
      s.neutral = s.getAverageColor();
      s.neutralLabel.text = '${s.neutral}';
      print('New neutral color: ${s.neutral}');
    }
    
    ctx.strokeStyle = 'red';
    if(s.neutral != null) {
      Color avg = s.getAverageColor();
      num diff_r = (s.neutral.r - avg.r).abs() / s.neutral.r;
      num diff_g = (s.neutral.g - avg.g).abs() / s.neutral.g;
      num diff_b = (s.neutral.b - avg.b).abs() / s.neutral.b;
      num diff_sum = (diff_r + diff_g + diff_b) * 100/3;
      //ctx.fillStyle = 'black';
      //String text = diff_sum.toStringAsFixed(3);
      //ctx.fillText(text, s.r.left + s.r.width / 2 - ctx.measureText(text).width/2, s.r.top + s.r.height / 2 - 10);
      if(diff_sum >= SECTOR_THRESHOLD) {
        // Detection in this frame, but not last frame 
        if(s.startTime == null) {
          s.startTime = window.performance.now();
        }
        ctx.strokeStyle = 'green';
      }
      
      if(s.startTime != null) {
        num diff = (window.performance.now() - s.startTime) / 1000.0;
        ctx.fillStyle = 'white';
        String text = diff.toStringAsFixed(2);
        ctx.fillText(text, s.r.left + s.r.width / 2 - ctx.measureText(text).width/2, s.r.top + s.r.height / 2 - 10);
        // THRESH
        if(diff > 2 && diff_sum > SECTOR_THRESHOLD) {
          s.roundTime = diff;
          notifyNewTime(diff);
          document.querySelector('#times').text = "${diff.toStringAsFixed(3)} sec\n" + document.querySelector('#times').text;
          s.startTime = null;
        }
      }
      
      if(s.roundTime != null) {
        ctx.fillStyle = 'white';
        String text = s.roundTime.toStringAsFixed(2);
        ctx.fillText(text, s.r.left + s.r.width / 2 - ctx.measureText(text).width/2, s.r.top + s.r.height / 2);
      }
    }
    
    ctx.beginPath();
    ctx.rect(s.r.left, s.r.top, s.r.width, s.r.height);
    ctx.stroke();
  });
  
  ctx.fillStyle = 'red';
  if(newSectorBegin != null && newSectorEnd != null) {
    ctx.beginPath();
    ctx.strokeStyle = 'red';
    ctx.rect(newSectorBegin.x, newSectorBegin.y, newSectorEnd.x - newSectorBegin.x, newSectorEnd.y - newSectorBegin.y);
    ctx.stroke();
  }
  
  if(notifyText != null) {
    notifyTextSize--;
    
    ctx.save();
    ctx.font = '${notifyTextSize}px Arial';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = 'white';
    ctx.fillText(notifyText, canvas.width/2 - ctx.measureText(notifyText).width/2, canvas.height/2);
    ctx.restore();
    
    if(notifyTextSize == 0) {
      notifyText = null;
    }
  }
  
  window.animationFrame.then(render);
}

void main() {
  createSectorButton.onClick.listen((MouseEvent ev) {
    createSectorButton.disabled = true;
    StreamSubscription sub;
    canvas.onMouseDown.first.then((MouseEvent ev) {
      newSectorBegin = ev.offset;
      sub = canvas.onMouseMove.listen((MouseEvent ev) {
        newSectorEnd = ev.offset;
      });
      document.onMouseUp.first.then((MouseEvent ev) {
        newSectorEnd = ev.offset;
        if(window.confirm('Save sector?')) {
          Rectangle r;
          r = new Rectangle(min(newSectorBegin.x, newSectorEnd.x), min(newSectorBegin.y, newSectorEnd.y), (newSectorEnd.x - newSectorBegin.x).abs(), (newSectorEnd.y - newSectorBegin.y).abs());
          sectors.add(new Sector(r));
        }
        newSectorBegin = null;
        newSectorEnd = null;
        sub.cancel();
        createSectorButton.disabled = false;
      });
    });
  });
  
  playButton.onClick.listen((MouseEvent ev) {
    if(video.paused) {
      playButton.text = 'Stop';
      video.play();
    } else {
      playButton.text = 'Play';
      video.pause();
      video.currentTime = 0;
    }
  });
  
  loadWebcamButton.onClick.listen((MouseEvent ev) {
    window.navigator.getUserMedia(video: true, audio: false).then((MediaStream ms) {
      video.src = Url.createObjectUrlFromStream(ms);
      video.play();
    });
  });
  
  window.animationFrame.then(render);
  
  /*
  HttpRequest.requestCrossOrigin('http://www.youtube.com/get_video_info?html5=1&video_id=xX-P-RVgwXw&cpn=v3H5Drv8tOjRkAzN&eurl=http%3A%2F%2Flocalhost%3A8080%2Findex.html&el=embedded&hl=de_DE&sts=16609&lact=4&width=640&height=480&authuser=1&pageid=112480856531646120478&ei=D-KSVZPcCtbBNJmGl4AM&iframe=1&c=WEB&cver=html5&cplayer=UNIPLAYER&cbr=Chrome&cbrver=43.0.2357.130&cos=Windows&cosver=6.1').then((String s) {
    print(s);
  });
  */
  
  // IFrameElement iframe = document.getElementById('iframe');
}
