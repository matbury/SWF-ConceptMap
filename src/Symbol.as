/**
* 
* @author Matt Bury - matbury@gmail.com
* @version $Id: Symbol.as,v 1.0 2011/06/23 matbury Exp $
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
*/

package {
	
	import flash.display.Sprite;
	import flash.filters.DropShadowFilter;
	import flash.events.*;
	
	public class Symbol extends Sprite {
		
		private var _label:Sprite;
		private var _i:uint;
		private var _toolType:String;
		private var _bgColor:Number;
		private var _dsf:DropShadowFilter;
		
		public function Symbol(bgColor:Number = 0xFFFFFF, i:uint = 0, toolType:String = "", label:Sprite = null) {
			if(label) {
				_label = label;
				_label.x = 10;
				_label.y = 10;
				addChild(_label);
			}
			_bgColor = bgColor;
			_i = i;
			_toolType = toolType;
			//
			_dsf = new DropShadowFilter(2,45,0,1,2,2);
			this.filters = [_dsf];
			this.mouseChildren = false;
			this.buttonMode = true;
			initBox();
			this.addEventListener(Event.ADDED_TO_STAGE, addedToStage);
		}
		
		private function initBox():void {
			this.graphics.lineStyle(1,0);
			this.graphics.beginFill(_bgColor,1);
			this.graphics.drawRect(0,0,20,20);
		}
		
		private function addedToStage(event:Event):void {
			this.removeEventListener(Event.ADDED_TO_STAGE, addedToStage);
			this.addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
		}
		
		private function mouseDown(event:MouseEvent):void {
			this.removeEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
			this.parent.parent.addEventListener(MouseEvent.MOUSE_UP, mouseUp);
			this.x += 2;
			this.y += 2;
			this.filters = [];
		}
		
		private function mouseUp(event:MouseEvent):void {
			this.parent.parent.removeEventListener(MouseEvent.MOUSE_UP, mouseUp);
			this.addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
			this.x -= 2;
			this.y -= 2;
			this.filters = [_dsf];
		}
		
		public function get i():uint {
			return _i;
		}
		
		public function get toolType():String {
			return _toolType;
		}
	}
}