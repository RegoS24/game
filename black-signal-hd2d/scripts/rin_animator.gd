extends RefCounted
## A time-driven HD sprite animator: no skeletal or 3D objects.
const SHEETS = {
 "idle":preload("res://assets/idle_smooth.webp"),"walk":preload("res://assets/walk_smooth.webp"),
 "run":preload("res://assets/run_smooth.webp"),"jump":preload("res://assets/jump_smooth.webp"),
 "crouch":preload("res://assets/crouch_smooth.webp"),"prone":preload("res://assets/prone_smooth.webp")
}
const COUNT = {"idle":32,"walk":40,"run":40,"jump":36,"crouch":32,"prone":36}
const DURATION = {"idle":1.8,"walk":1.0,"run":0.72,"jump":0.78,"crouch":0.48,"prone":0.66}
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
 return name=="idle" or name=="walk" or name=="run"
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
 blend_time=0.14 if is_loop(previous_clip) and is_loop(clip) else 0.085
func frame_index() -> int:
 return clampi(int(floor(frame+0.5)),0,int(COUNT[clip])-1)
func request_crouch() -> void:
 if not jumping: target_stance="stand" if target_stance=="crouch" else "crouch"
func request_prone() -> void:
 if not jumping: target_stance="stand" if target_stance=="prone" else "prone"
func request_jump() -> void:
 if stance=="stand" and target_stance=="stand" and transition.is_empty() and not jumping: jump_requested=true
func speed_factor() -> float:
 if not transition.is_empty(): return 0.18
 if stance=="prone": return 0.24
 if stance=="crouch": return 0.50
 return 1.0
func state_label() -> String:
 if jumping: return "ПРЫЖОК"
 if not transition.is_empty(): return "СМЕНА СТОЙКИ"
 if stance=="prone": return "ЛЁЖА"
 if stance=="crouch": return "ПРИСЕД"
 if locomotion: return "БЕГ" if running else "ХОДЬБА"
 return "ПОКОЙ"
func tick(dt: float, movement: float, sprint: bool) -> void:
 dt=clampf(dt,0.0,0.05)
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
 if stance!="stand":
  if clip!=stance: set_clip(stance,float(COUNT[stance])-1)
  frame=float(COUNT[stance])-1
  return
 locomotion=movement>0.15 if not locomotion else movement>0.045
 var desired: String="idle" if not locomotion else ("run" if sprint else "walk")
 if desired!=clip:
  var preserve: bool=(clip=="walk" or clip=="run") and (desired=="walk" or desired=="run")
  set_clip(desired,0.0,preserve)
 var rate: float=float(COUNT[clip])/float(DURATION[clip])
 if locomotion: rate*=lerpf(0.72,1.0,clampf(moving,0.0,1.0))
 frame=fposmod(frame+dt*rate,float(COUNT[clip]))
func paint(canvas: CanvasItem, at: Vector2, scale_factor: float, extra: Vector2=Vector2.ZERO) -> void:
 var dst:=Rect2(at-Vector2(128,224)*scale_factor+extra,Vector2(256,256)*scale_factor)
 var a:float=mix*mix*(3.0-2.0*mix)
 if a<1.0: draw_frame(canvas,previous_clip,clampi(int(floor(previous_frame+0.5)),0,int(COUNT[previous_clip])-1),dst,1.0-a)
 draw_frame(canvas,clip,frame_index(),dst,a)
func draw_frame(canvas: CanvasItem,name: String,number: int,dst: Rect2,alpha: float) -> void:
 var src:=Rect2(Vector2(float(number%8)*256.0,floorf(float(number)/8.0)*256.0),Vector2(256,256))
 canvas.draw_texture_rect_region(SHEETS[name],dst,src,Color(1,1,1,alpha))
