/**
* 
* @author Matt Bury - matt@matbury.com
* @version $Id: ConceptMap, v 1.0 2013/08/13 matbury
* @licence http://www.gnu.org/copyleft/gpl.html GNU Public Licence
* Copyright (C) 2011  Matt Bury
*
* This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
* 
*/

package 
{
	import flash.display.Sprite;
	import flash.display.StageScaleMode;
	import flash.display.StageAlign;
	import flash.display.BitmapData;
	import flash.display.Bitmap;
	import flash.utils.ByteArray;
	import flash.ui.Mouse;
	import flash.ui.MouseCursor;
	import flash.events.*;
	import flash.text.*;
	import flash.net.*;
	import flash.utils.getTimer;
	import flash.utils.Timer;
	import flash.filters.DropShadowFilter;
	import com.adobe.images.PNGEncoder; // Static class, doesn't need instantiating
	import com.adobe.images.JPGEncoder; // Normal class, needs instantiating
	import com.matbury.sam.data.Amf; // Normal class, communicates with Moodle (AMF3)
	import com.matbury.sam.data.FlashVars; // Static class, easy way to manage SWF Activity Module data
	/**
	 * ...
	 * @author Matt Bury
	 */
	public class Main extends Sprite 
	{
		private var _version:String = "2013.08.13";
		private var _amf:Amf;
		private var _dsf:DropShadowFilter;
		private var _um:TextField;
		// tool types: "", "pen", "rect", "oval", "move"
		private var _toolType:String = "pen"; // start with pen tool
		private var _toolX:int = 0;
		private var _thicknesses:Array; // available thicknesses of pen tool
		private var _thickness:uint = 2; // starting thickness
		private var _colors:Array; // available colours
		private var _color:Number; // current colour
		private var _shape:Sprite;
		private var _sprites:Array; // drawn objects that can be undone
		private var _dragSprites:Array; // draggable sprites
		private var _sprite:Sprite; // current sprite being drawn
		private var _tf:TextField; // current text field
		private var _controls:Array; // tool selection controls
		private var _shapeStartX:int;
		private var _shapeStartY:int;
		private var _byteArray:ByteArray; // stores bitmap data to send to server
		private var _imageType:String = "png"; // File extension and ByteArray encoding to use png or jpg
		
		public function Main():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init(e:Event = null):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			// entry point
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			// Set Moodle context parameters passed in through FlashVars
			FlashVars.vars = this.root.loaderInfo.parameters;
			// If imagetype parameter is passed in, set it.
			if(this.root.loaderInfo.parameters.imagetype) {
				_imageType = this.root.loaderInfo.parameters.imagetype;
			}
			_dsf = new DropShadowFilter(2,45,0x000000,1,2,2);
			initInteraction();
		}
		
		/*
		################################################## INTERACTION ##################################################
		*/
		// Initialise learning interaction
		private function initInteraction():void {
			_sprites = new Array();
			initColors();
			initThicknesses();
			initRectangleTool();
			initOvalTool();
			initTextTool();
			initMoveTool();
			initUndoTool();
			initCameraTool();
			stage.addEventListener(MouseEvent.MOUSE_DOWN, penToolDown); // start with pen tool
		}
		
		/*
		################################################## MANAGE TOOLS ##################################################
		*/
		// Manage tool properties according what user selects
		private function toolUp(event:MouseEvent):void {
			removeListeners();
			var symbol:Symbol = event.currentTarget as Symbol;
			var toolType:String = symbol.toolType;
			switch(toolType) {				
				case "pen":
				stage.addEventListener(MouseEvent.MOUSE_DOWN, penToolDown);
				Mouse.cursor = MouseCursor.AUTO;
				_thickness = _thicknesses[symbol.i];
				_toolType = "pen";
				break;
				
				case "rect":
				stage.addEventListener(MouseEvent.MOUSE_DOWN, rectToolDown);
				Mouse.cursor = MouseCursor.AUTO;
				_toolType = "rect";
				break;
				
				case "oval":
				stage.addEventListener(MouseEvent.MOUSE_DOWN, ovalToolDown);
				Mouse.cursor = MouseCursor.AUTO;
				_toolType = "oval";
				break;
				
				case "text":
				stage.addEventListener(MouseEvent.MOUSE_DOWN, textToolDown);
				Mouse.cursor = MouseCursor.IBEAM;
				_toolType = "text";
				break;
				
				case "move":
				stage.addEventListener(MouseEvent.MOUSE_DOWN, moveToolDown);
				Mouse.cursor = MouseCursor.HAND;
				_toolType = "move";
				break;
			}
		}
		
		private function removeListeners():void {
			if(_toolType == "pen") {
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, penToolDown);
			}
			if(_toolType == "rect") {
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, rectToolDown);
			}
			if(_toolType == "oval") {
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, ovalToolDown);
			}
			if(_toolType == "text") {
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, textToolDown);
			}
			if(_toolType == "move") {
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, moveToolDown);
			}
		}
		
		/*
		################################################## COLOURS ##################################################
		*/
		// avaliable colours
		// for more colours, just add them to _colors array
		private function initColors():void {
			_colors = new Array(0x000000,0x0000DD,0x00BB00,0xFFFF00,0xDD0000,0xDD00DD);
			_color = _colors[0];
			var len:uint = _colors.length;
			for(var i:uint = 0; i < len; i++) {
				var symbol:Symbol = new Symbol(_colors[i],i,"");
				symbol.addEventListener(MouseEvent.MOUSE_UP, colorUp);
				symbol.x = _toolX;
				symbol.y = 2;
				addChild(symbol);
				_toolX = symbol.x + symbol.width + 2;
			}
		}
		
		private function colorUp(event:MouseEvent):void {
			var symbol:Symbol = event.currentTarget as Symbol;
			_color = _colors[symbol.i];
		}
		
		/*
		################################################## PEN TOOL ##################################################
		*/
		// avaliable pen thicknesses
		// for more thicknesses, just add them to _thicknesses array
		private function initThicknesses():void {
			_thicknesses = new Array(1,2,4,8,16);
			_thickness = _thicknesses[0];
			var len:uint = _thicknesses.length;
			for(var i:uint = 0; i < len; i++) {
				var dot:Sprite = new Sprite();
				dot.graphics.beginFill(_color);
				dot.graphics.drawCircle(0,0,_thicknesses[i] * 0.5);
				dot.graphics.endFill();
				var symbol:Symbol = new Symbol(0xFFFFFF,i,"pen",dot);
				symbol.addEventListener(MouseEvent.MOUSE_UP, toolUp);
				symbol.x = _toolX;
				symbol.y = 2;
				addChild(symbol);
				_toolX = symbol.x + symbol.width + 2;
			}
		}
		
		private function penToolDown(event:MouseEvent):void {
			if(mouseY > 20) {
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, penToolDown);
				stage.addEventListener(MouseEvent.MOUSE_UP, penToolUp);
				stage.addEventListener(MouseEvent.MOUSE_MOVE, penToolMove);
				var sprite:Sprite = new Sprite();
				sprite.x = mouseX;
				sprite.y = mouseY;
				var dot:Sprite = new Sprite();
				dot.graphics.beginFill(_color);
				dot.graphics.drawCircle(0,0,_thickness * 0.5);
				dot.graphics.endFill();
				sprite.addChild(dot);
				sprite.graphics.lineStyle(_thickness,_color);
				addChild(sprite);
				_sprite = sprite;
				_sprites.push(sprite);
			}
		}
		
		private function penToolUp(event:MouseEvent):void {
			stage.removeEventListener(MouseEvent.MOUSE_UP, penToolUp);
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, penToolMove);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, penToolDown);
		}
		
		private function penToolMove(event:MouseEvent):void {
			if(mouseY > 20) {
				_sprite.graphics.lineTo(_sprite.mouseX,_sprite.mouseY);
			}
		}
		
		/*
		################################################## RECTANGLE TOOL #####################################################
		*/
		// Draw semi transparent rectangle shapes on stage
		private function initRectangleTool():void {
			var rect:Sprite = new Sprite();
			rect.graphics.beginFill(0xBBBBBB);
			rect.graphics.drawRect(-6,-6,12,12);
			rect.graphics.endFill();
			var symbol:Symbol = new Symbol(0xFFFFFF,0,"rect",rect);
			symbol.addEventListener(MouseEvent.MOUSE_UP, toolUp);
			symbol.x = _toolX;
			symbol.y = 2;
			addChild(symbol);
			_toolX = symbol.x + symbol.width + 2;
		}
		
		private function rectToolDown(event:MouseEvent):void {
			if(mouseY > 20) {
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, rectToolDown);
				stage.addEventListener(MouseEvent.MOUSE_UP, rectToolUp);
				stage.addEventListener(MouseEvent.MOUSE_MOVE, rectToolMove);
				_shapeStartX = mouseX;
				_shapeStartY = mouseY;
				_shape = new Sprite();
				_shape.graphics.beginFill(_color,0.25);
				_shape.graphics.drawRect(0,0,1,1);
				_shape.graphics.endFill();
				_shape.x = mouseX;
				_shape.y = mouseY;
				addChild(_shape);
				_sprites.push(_shape);
			}
		}
		
		private function rectToolMove(event:MouseEvent):void {
			if(mouseY > 20) {
				_shape.width = mouseX - _shapeStartX;
				_shape.height = mouseY - _shapeStartY;
			}
		}
		
		private function rectToolUp(event:MouseEvent):void {
			stage.removeEventListener(MouseEvent.MOUSE_UP, rectToolUp);
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, rectToolMove);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, rectToolDown);
		}
		
		/*
		################################################## OVAL TOOL #####################################################
		*/
		// Draw semi transparent oval shapes on stage
		private function initOvalTool():void {
			var ellipse:Sprite = new Sprite();
			ellipse.graphics.beginFill(0xBBBBBB);
			ellipse.graphics.drawEllipse(-7,-7,14,14);
			ellipse.graphics.endFill();
			var symbol:Symbol = new Symbol(0xFFFFFF,0,"oval",ellipse);
			symbol.addEventListener(MouseEvent.MOUSE_UP, toolUp);
			symbol.x = _toolX;
			symbol.y = 2;
			addChild(symbol);
			_toolX = symbol.x + symbol.width + 2;
		}
		
		private function ovalToolDown(event:MouseEvent):void {
			if(mouseY > 20) {
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, ovalToolDown);
				stage.addEventListener(MouseEvent.MOUSE_UP, ovalToolUp);
				stage.addEventListener(MouseEvent.MOUSE_MOVE, ovalToolMove);
				_shapeStartX = mouseX;
				_shapeStartY = mouseY;
				_shape = new Sprite();
				_shape.graphics.beginFill(_color,0.25);
				_shape.graphics.drawEllipse(0,0,1,1);
				_shape.graphics.endFill();
				_shape.x = mouseX;
				_shape.y = mouseY;
				addChild(_shape);
				_sprites.push(_shape);
			}
		}
		
		private function ovalToolMove(event:MouseEvent):void {
			if(mouseY > 20) {
				_shape.width = mouseX - _shapeStartX;
				_shape.height = mouseY - _shapeStartY;
			}
		}
		
		private function ovalToolUp(event:MouseEvent):void {
			stage.removeEventListener(MouseEvent.MOUSE_UP, ovalToolUp);
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, ovalToolMove);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, ovalToolDown);
		}
		
		/*
		################################################## TEXT TOOL #####################################################
		*/
		// Draw text fields and text on stage
		private function initTextTool():void {
			var sprite:Sprite = new Sprite();
			var f:TextFormat = new TextFormat("Times New Roman",18,0,true);
			var tf:TextField = new TextField();
			tf.width = 16;
			tf.height = 20;
			tf.x = -7;
			tf.y = -12;
			tf.defaultTextFormat = f;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.text = "T";
			sprite.addChild(tf);
			var symbol:Symbol = new Symbol(0xFFFFFF,0,"text",sprite);
			symbol.addEventListener(MouseEvent.MOUSE_UP, toolUp);
			symbol.x = _toolX;
			symbol.y = 2;
			addChild(symbol);
			_toolX = symbol.x + symbol.width + 2;
		}
		
		private function textToolDown(event:MouseEvent):void {
			if(mouseY > 20) {
				_sprite = new Sprite();
				_sprite.graphics.beginFill(_color);
				_sprite.graphics.drawCircle(-8,12,5);
				_sprite.graphics.endFill();
				_sprite.x = mouseX;
				_sprite.y = mouseY;
				_sprite.buttonMode = true;
				var f:TextFormat = new TextFormat("Trebuchet MS",14,_color,true);
				_tf = new TextField();
				_tf.defaultTextFormat = f;
				_tf.autoSize = TextFieldAutoSize.LEFT;
				_tf.type = TextFieldType.INPUT;
				_tf.multiline = true;
				_sprite.addChild(_tf);
				addChild(_sprite);
				_sprites.push(_sprite);
				stage.focus = _tf;
			}
		}
		
		/*
		################################################## MOVE TOOL #####################################################
		*/
		// Drag and drop drawn objects on stage
		private function initMoveTool():void {
			var hand:Hand = new Hand();
			hand.x = -16;
			hand.y = -16;
			var symbol:Symbol = new Symbol(0xFFFFFF,0,"move",hand);
			symbol.addEventListener(MouseEvent.MOUSE_UP, toolUp);
			symbol.x = _toolX;
			symbol.y = 2;
			addChild(symbol);
			_toolX = symbol.x + symbol.width + 2;
		}
		
		private function moveToolDown(event:MouseEvent):void {
			if(mouseY > 20) {
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, moveToolDown);
				stage.addEventListener(MouseEvent.MOUSE_UP, moveToolUp);
				_dragSprites = new Array();
				var len:uint = _sprites.length;
				for(var i:uint = 0; i < len; i++) {
					if(_sprites[i].hitTestPoint(mouseX,mouseY,true)) {
						_dragSprites.push(_sprites[i]);
						_sprites[i].startDrag();
					}
				}
			}
		}
		
		private function moveToolUp(event:MouseEvent):void {
			stage.addEventListener(MouseEvent.MOUSE_DOWN, moveToolDown);
			stage.removeEventListener(MouseEvent.MOUSE_UP, moveToolUp);
			var len:uint = _dragSprites.length;
			for(var i:uint = 0; i < len; i++) {
				_dragSprites[i].stopDrag();
			}
		}
		
		/*
		################################################## UNDO TOOL #####################################################
		*/
		// Removes last drawn object from stage
		private function initUndoTool():void {
			var undo:Undo = new Undo();
			var symbol:Symbol = new Symbol(0xFFFFFF,0,"",undo);
			symbol.addEventListener(MouseEvent.MOUSE_UP, undoUp);
			symbol.x = _toolX;
			symbol.y = 2;
			addChild(symbol);
			_toolX = symbol.x + symbol.width + 2;
		}
		
		private function undoUp(event:MouseEvent):void {
			if(_sprites.length > 0) {
				removeChild(_sprites[_sprites.length - 1]);
				_sprites.pop();
			}
		}
		
		/*
		################################################## CAMERA TOOL #####################################################
		*/
		// Takes snapshot of current screen
		private function initCameraTool():void {
			var cam:Cam = new Cam();
			var symbol:Symbol = new Symbol(0xFFFFFF,0,"",cam);
			symbol.addEventListener(MouseEvent.MOUSE_UP, takeSnapshot);
			symbol.x = _toolX;
			symbol.y = 2;
			addChild(symbol);
			_toolX = symbol.x + symbol.width + 2;
		}
		
		private function takeSnapshot(event:MouseEvent):void {
			// Define the dimensions of the area to record
			var bitmapData:BitmapData = new BitmapData(stage.stageWidth,stage.stageHeight);
			// Record a DisplayObject. In this case the stage cast as a Sprite.
			bitmapData.draw(Sprite(this));
			// Record it in the selected file format
			if(_imageType == "png") {
				_byteArray = PNGEncoder.encode(bitmapData);
				sendData();
			} else if(_imageType == "jpg") {
				var jpgEncoder:JPGEncoder = new JPGEncoder();
				_byteArray = jpgEncoder.encode(bitmapData);
				sendData();
			} else {
				// If it isn't defined, cannot record so tell user.
				showMessage("Image type not specified");
			}
		}
		
		/*
		################################################## USER MESSAGE #####################################################
		*/
		// Show text message to user
		private function showMessage(message:String):void {
			// If there's a previous message, remove it
			if(_um) {
				removeChild(_um);
				_um = null;
			}
			var f:TextFormat = new TextFormat("Trebuchet MS",18,0,true);
			f.align = TextFormatAlign.CENTER;
			_um = new TextField();
			_um.defaultTextFormat = f;
			_um.autoSize = TextFieldAutoSize.LEFT;
			_um.background = true;
			_um.selectable = false;
			_um.filters = [_dsf];
			_um.text = message;
			_um.x = stage.stageWidth * 0.5 - (_um.width * 0.5);
			_um.y = stage.stageHeight * 0.5 - (_um.height * 0.5);
			addChild(_um);
			startMessageTimer();
		}
		
		// Show message for 5 seconds
		private function startMessageTimer():void {
			var timer:Timer = new Timer(1000,5); // 5 * 1000 milliseconds
			timer.addEventListener(TimerEvent.TIMER_COMPLETE, timerComplete);
			timer.start();
		}
		
		// Delete message
		private function timerComplete(event:TimerEvent):void {
			event.target.removeEventListener(TimerEvent.TIMER_COMPLETE, timerComplete);
			if(_um) {
				removeChild(_um);
				_um = null;
			}
		}
		
		/*
		################################################## SEND DATA #####################################################
		*/
		// Send the snapshot to the server to be saved by Snapshot.php
		private function sendData():void {
			// Tell user what we're doing.
			showMessage("Saving your image...");
			// Send the ByteArray to AMFPHP
			_amf = new Amf(); // create Flash Remoting API object
			_amf.addEventListener(Amf.GOT_DATA, gotDataHandler); // listen for server response
			_amf.addEventListener(Amf.FAULT, faultHandler); // listen for server fault
			var obj:Object = new Object(); // create an object to hold data sent to the server
			obj.feedback = ""; // (String) optional
			obj.feedbackformat = Math.floor(getTimer() / 1000); // (int) elapsed time in seconds
			obj.gateway = FlashVars.gateway; // (String) AMFPHP gateway URL
			obj.instance = FlashVars.instance; // (int) Moodle instance ID
			obj.rawgrade = 0; // (Number) grade, normally 0 - 100 but depends on grade book settings
			obj.pushgrade = true;
			obj.servicefunction = "Snapshot.amf_save_snapshot"; // (String) ClassName.method_name
			obj.swfid = FlashVars.swfid; // (int) activity ID
			obj.bytearray = _byteArray;
			obj.imagetype = _imageType; // PNGExport = png, JPGExport = jpg
			_amf.getObject(obj); // send the data to the server
		}
		
		// Connection to AMFPHP succeeded
		// Manage returned data and inform user
		private function gotDataHandler(event:Event):void {
			// Clean up listeners
			_amf.removeEventListener(Amf.GOT_DATA, gotDataHandler);
			_amf.removeEventListener(Amf.FAULT, faultHandler);
			// Check if grade was sent successfully
			switch(_amf.obj.result) {
				//
				case "SUCCESS":
				showMessage("Your image was saved successfully.");
				navigateToImage(_amf.obj.imageurl);
				break;
				//
				case "NO_SNAPSHOT_DIRECTORY":
				showMessage(_amf.obj.imageurl);
				break;
				//
				case "FILE_NOT_WRITTEN":
				showMessage("There was a problem. Your image was not saved.");
				break;
				//
				case "NO_PERMISSION":
				showMessage("You do not have permission to save images.");
				break;
				//
				default:
				var message:String = "Unknown error.";
				for(var s:String in _amf.obj) {
					message += "\n" + s + " = " + _amf.obj[s].toString();
				}
				showMessage(message);
			}
		}
		
		// Display server errors
		private function faultHandler(event:Event):void {
			// clean up listeners
			_amf.removeEventListener(Amf.GOT_DATA, gotDataHandler);
			_amf.removeEventListener(Amf.FAULT, faultHandler);
			var message:String = "There was a problem.\nYour image was not saved.";
			for(var s:String in _amf.obj.info) { // trace out returned data
				message += "\n" + s + "=" + _amf.obj.info[s];
			}
			_um.text = message;
			showMessage(message);
		}
		
		private function navigateToImage(url:String):void {
			// Open returned URL in a new window,
			var request:URLRequest = new URLRequest(url);
			navigateToURL(request,"_blank");
			// or...
			// redirect to Moodle grade book
			//var gradebook:String = FlashVars.gradebook;
			//navigateToURL(request,"_self");
		}
	}
}