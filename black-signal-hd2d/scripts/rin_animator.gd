extends RefCounted
## A time-driven HD sprite animator: no skeletal or 3D objects.
const PackedFrames = preload("res://scripts/rin_frames_generated.gd")
const SHEETS = PackedFrames.SHEETS
const LAYOUT = PackedFrames.LAYOUT
const ANIMATION_FPS: float = 90.0
const COUNT = {"idle":162,"walk":90,"run":72,"jump":72,"crouch":45,"prone":61,"crouch_walk":104,"crawl":136}
const TILE_W: float = 384.0
const TILE_H: float = 512.0
const DURATION = {"idle":162.0/90.0,"walk":90.0/90.0,"run":72.0/90.0,"jump":71.0/90.0,"crouch":44.0/90.0,"prone":60.0/90.0,"crouch_walk":104.0/90.0,"crawl":136.0/90.0}
var clip: String = "idle"
var frame: float = 0.0
var previous_clip: String = "idle"
var previous_frame: float = 0.0
var mix: float = 1.0
var stance: String = "stand"
var target_stance: String = "stand"
var transition: String = ""
var jumping: bool = false
var moving: float = 0.0
var running: bool = false
var jump_requested: bool = false
var locomotion: bool = false
var blend_time: float = 0.12
func is_loop(name: String) -> bool:
 return name=="idle" or name=="walk" or name=="run" or name=="crouch_walk" or name=="crawl"
func set_clip(name: String, start: float = 0.0, keep_phase: bool = false) -> void:
 if name==clip:
  if not keep_phase: frame=start
  return
 previous_clip=clip
 previous_frame=frame
 var phase: float=frame/float(COUNT[clip])
 clip=name
 frame=phase*float(COUNT[name]) if keep_phase else start
 mix=0.0
 blend_time=0.065 if is_loop(previous_clip) and is_loop(clip) else 0.045
func frame_index() -> int:
 return index_for(clip,frame)
func index_for(name: String, at_frame: float) -> int:
 var n: int=int(COUNT[name])
 return posmod(int(floor(at_frame+0.5)),n) if is_loop(name) else clampi(int(floor(at_frame+0.5)),0,n-1)
func jump_lift() -> float:
 if not jumping: return 0.0
 var t: float=clampf(frame/float(COUNT["jump"]-1),0.0,1.0)
 return 36.0*4.0*t*(1.0-t)
func request_crouch() -> void:
 if not jumping: target_stance="stand" if target_stance=="crouch" else "crouch"
func request_prone() -> void:
 if not jumping: target_stance="stand" if target_stance=="prone" else "prone"
func request_jump() -> void:
 if stance=="stand" and target_stance=="stand" and transition.is_empty() and not jumping: jump_requested=true
func speed_factor() -> float:
 if not transition.is_empty(): return 0.06
 if stance=="prone": return 0.24
 if stance=="crouch": return 0.50
 return 1.0
func state_label() -> String:
 if jumping: return "ПРЫЖОК"
 if not transition.is_empty(): return "СМЕНА СТОЙКИ"
 if stance=="prone": return "ПОЛЗАНИЕ" if clip=="crawl" else "ЛЁЖА"
 if stance=="crouch": return "ХОДЬБА В ПРИСЕДЕ" if clip=="crouch_walk" else "ПРИСЕД"
 if locomotion: return "БЕГ" if running else "ХОДЬБА"
 return "ПОКОЙ"
func tick(dt: float, movement: float, sprint: bool) -> void:
 dt=clampf(dt,0.0,0.20)
 moving=lerpf(moving,movement,1.0-exp(-dt*14.0))
 running=sprint
 mix=minf(1.0,mix+dt/blend_time)
 if mix<1.0 and is_loop(previous_clip):
  previous_frame=fposmod(previous_frame+dt*float(COUNT[previous_clip])/float(DURATION[previous_clip]),float(COUNT[previous_clip]))
 if jumping:
  frame+=dt*float(COUNT["jump"]-1)/float(DURATION["jump"])
  if frame>=float(COUNT["jump"])-1: 
   jumping=false
   frame=float(COUNT["jump"])-1
  else: return
 if not transition.is_empty():
  # Reverse a stance transition immediately when the user changes their mind.
  if clip=="crouch": transition="up_crouch" if target_stance=="stand" else "down_crouch"
  elif clip=="prone": transition="down_prone" if target_stance=="prone" else "up_prone"
  var up: bool=transition.begins_with("up")
  frame+=dt*float(COUNT[clip]-1)/float(DURATION[clip])*(-1.0 if up else 1.0)
  if up and frame<=0.0:
   frame=0.0;stance="crouch" if clip=="prone" else "stand";transition=""
  elif not up and frame>=float(COUNT[clip])-1:
   frame=float(COUNT[clip])-1;stance="prone" if clip=="prone" else "crouch";transition=""
  else: return
 if stance!=target_stance:
  if stance=="prone":
   transition="up_prone";set_clip("prone",float(COUNT["prone"])-1)
  elif stance=="stand":
   transition="down_crouch";set_clip("crouch",0.0)
  elif target_stance=="prone":
   transition="down_prone";set_clip("prone",0.0)
  else:
   transition="up_crouch";set_clip("crouch",float(COUNT["crouch"])-1)
  return
 if jump_requested:
  jump_requested=false;jumping=true;set_clip("jump",0.0);return
 locomotion=movement>0.12 if not locomotion else moving>0.055
 if stance!="stand":
  var low_clip: String="crawl" if stance=="prone" else "crouch_walk"
  if not locomotion:
   if clip!=stance:set_clip(stance,float(COUNT[stance])-1)
   frame=float(COUNT[stance])-1
   return
  if clip!=low_clip:set_clip(low_clip,0.0)
  advance_gait(dt)
  return
 var desired: String="idle" if not locomotion else ("run" if sprint else "walk")
 if desired!=clip:
  var preserve: bool=(clip=="walk" or clip=="run") and (desired=="walk" or desired=="run")
  set_clip(desired,0.0,preserve)
 if locomotion:advance_gait(dt)
 else:frame=fposmod(frame+dt*float(COUNT[clip])/float(DURATION[clip]),float(COUNT[clip]))

func advance_gait(dt: float) -> void:
 # Fractional phase is continuous throughout the full two-leg cycle.
 var rate: float=float(COUNT[clip])/float(DURATION[clip])*clampf(moving,0.0,1.0)
 frame=fposmod(frame+dt*rate,float(COUNT[clip]))
func paint(canvas: CanvasItem, at: Vector2, scale_factor: float, extra: Vector2=Vector2.ZERO) -> void:
 var dst:=Rect2(at-Vector2(96,224)*scale_factor+extra-Vector2(0,jump_lift()),Vector2(192,256)*scale_factor)
 var a:float=mix*mix*(3.0-2.0*mix)
 if a<1.0: draw_frame(canvas,previous_clip,index_for(previous_clip,previous_frame),dst,1.0-a)
 draw_frame(canvas,clip,frame_index(),dst,a)
func draw_frame(canvas: CanvasItem,name: String,number: int,dst: Rect2,alpha: float) -> void:
 # Packed pages retain the original 384×512 coordinate system and feet anchor.
 var layout: Array=LAYOUT[name]
 var page_size: int=int(layout[5])
 var page: int=floori(float(number)/float(page_size))
 var local_index: int=number%page_size
 var cols: int=int(layout[4])
 var tile:=Vector2(float(layout[2]),float(layout[3]))
 var offset:=Vector2(float(layout[0]),float(layout[1]))
 var gutter: float=float(layout[6])
 var stride:=tile+Vector2(gutter*2.0,gutter*2.0)
 var src:=Rect2(Vector2(float(local_index%cols),float(floori(float(local_index)/float(cols))))*stride+Vector2(gutter,gutter),tile)
 var ratio:=dst.size/Vector2(TILE_W,TILE_H)
 var region:=Rect2(dst.position+offset*ratio,tile*ratio)
 var sheet: Texture2D=SHEETS[name][page]
 canvas.draw_texture_rect_region(sheet,region,src,Color(1,1,1,alpha))
