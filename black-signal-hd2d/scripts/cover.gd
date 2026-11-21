extends RefCounted
## Deterministic planar cover collision and hitscan occlusion for canvas world.
## Physics use world metres; this is not a fake screen-space box collision.
const STEP: float=0.16

static func circle_overlaps(p: Vector2,radius: float,rects: Array[Rect2]) -> bool:
 for rect in rects:
  var q:=Vector2(clampf(p.x,rect.position.x,rect.end.x),clampf(p.y,rect.position.y,rect.end.y))
  if p.distance_squared_to(q)<radius*radius:
   return true
 return false

static func segment_blocked(a: Vector2,b: Vector2,rects: Array[Rect2]) -> bool:
 # Liang-Barsky slab clipping; Rect2 in Godot does not provide intersects_segment().
 var delta: Vector2=b-a
 for rect in rects:
  var enter: float=0.0
  var exit: float=1.0
  var valid: bool=true
  for axis in range(2):
   var start: float=a.x if axis==0 else a.y
   var ray: float=delta.x if axis==0 else delta.y
   var low: float=rect.position.x if axis==0 else rect.position.y
   var high: float=rect.end.x if axis==0 else rect.end.y
   if absf(ray)<0.000001:
    if start<low or start>high:
     valid=false
     break
   else:
    var near: float=(low-start)/ray
    var far: float=(high-start)/ray
    if near>far:
     var swap: float=near
     near=far
     far=swap
    enter=maxf(enter,near)
    exit=minf(exit,far)
    if enter>exit:
     valid=false
     break
  if valid:return true
 return false

static func move_circle(origin: Vector2,delta: Vector2,radius: float,rects: Array[Rect2]) -> Vector2:
 # Small substeps avoid tunneling through thin crates at low frame rates.
 # Resolving one axis at a time lets units slide along obstacle faces.
 if delta.length_squared()<0.0000001:return origin
 var steps: int=clampi(ceili(delta.length()/STEP),1,128)
 var move: Vector2=delta/float(steps)
 var result: Vector2=origin
 for i in range(steps):
  var side: Vector2=result+Vector2(move.x,0)
  if not circle_overlaps(side,radius,rects):result=side
  side=result+Vector2(0,move.y)
  if not circle_overlaps(side,radius,rects):result=side
 return result

static func nearest_unblocked_flank(p: Vector2,target: Vector2,radius: float,step: float,rects: Array[Rect2],prefer_right: bool) -> Vector2:
 var ray: Vector2=(target-p).normalized()
 if ray.length_squared()<0.0001:return p
 var across: Vector2=Vector2(-ray.y,ray.x)
 var right_hand: float=1.0 if prefer_right else -1.0
 var primary: Vector2=move_circle(p,across*right_hand*step,radius,rects)
 var secondary: Vector2=move_circle(p,-across*right_hand*step,radius,rects)
 # Take the wider open side. A small preferred sign breaks symmetrical ties.
 return primary if primary.distance_squared_to(p)>=secondary.distance_squared_to(p) else secondary
