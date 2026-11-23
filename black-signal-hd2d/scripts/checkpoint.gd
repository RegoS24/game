extends RefCounted
## Versioned, validated Chapter 01 checkpoint. Never stores user settings or personal-best records.
const SAVE_PATH: String = "user://black_signal_checkpoint_v1.json"
const VERSION: int = 1

static func validate(data: Variant) -> bool:
 if typeof(data)!=TYPE_DICTIONARY:return false
 if typeof(data.get("version",null))!=TYPE_INT and typeof(data.get("version",null))!=TYPE_FLOAT:return false
 if float(data["version"])!=float(VERSION):return false
 var position: Variant=data.get("position",[])
 if typeof(position)!=TYPE_ARRAY or position.size()!=2:return false
 for coordinate in position:
  if typeof(coordinate)!=TYPE_FLOAT and typeof(coordinate)!=TYPE_INT:return false
 if not is_finite(float(position[0])) or not is_finite(float(position[1])):return false
 if absf(float(position[0]))>5.9 or float(position[1])< -65.0 or float(position[1])>215.0:return false
 for key in ["yaw","pitch","time"]:
  var n: Variant=data.get(key,null)
  if typeof(n)!=TYPE_FLOAT and typeof(n)!=TYPE_INT:return false
 if absf(float(data["yaw"]))>100000.0 or float(data["pitch"])< -0.36 or float(data["pitch"])>0.62:return false
 if not is_finite(float(data["yaw"])) or not is_finite(float(data["pitch"])) or not is_finite(float(data["time"])):return false
 if float(data["time"])<0.0 or float(data["time"])>86400.0:return false
 for key in ["hp","ammo","reserve","kills","phase"]:
  if typeof(data.get(key,null))!=TYPE_FLOAT and typeof(data.get(key,null))!=TYPE_INT:return false
 for key in ["hp","ammo","reserve","kills","phase"]:
  var value: float=float(data[key])
  if not is_finite(value) or value!=float(int(value)):return false
 if int(data["hp"])<1 or int(data["hp"])>100:return false
 if int(data["ammo"])<0 or int(data["ammo"])>12 or int(data["reserve"])<0 or int(data["reserve"])>9999:return false
 if int(data["kills"])<0 or int(data["kills"])>6 or int(data["phase"])<0 or int(data["phase"])>2:return false
 var stations: Variant=data.get("stations",[])
 if typeof(stations)!=TYPE_ARRAY or stations.size()>3:return false
 var unique_stations: Dictionary={}
 for station in stations:
  if typeof(station)!=TYPE_INT and typeof(station)!=TYPE_FLOAT:return false
  var station_value: float=float(station)
  if not is_finite(station_value):return false
  if station_value<0.0 or station_value>2.0 or station_value!=floorf(station_value):return false
  if unique_stations.has(int(station)):return false
  unique_stations[int(station)]=true
 var enemies: Variant=data.get("enemies",[])
 if typeof(enemies)!=TYPE_ARRAY or enemies.size()!=6:return false
 var dead: int=0
 for i in range(6):
  var enemy: Variant=enemies[i]
  if typeof(enemy)!=TYPE_DICTIONARY:return false
  if typeof(enemy.get("kind",null))!=TYPE_INT and typeof(enemy.get("kind",null))!=TYPE_FLOAT:return false
  if not is_finite(float(enemy["kind"])) or float(enemy["kind"])!=float(i):return false
  var p: Variant=enemy.get("position",[])
  if typeof(p)!=TYPE_ARRAY or p.size()!=2:return false
  for coordinate in p:
   if typeof(coordinate)!=TYPE_FLOAT and typeof(coordinate)!=TYPE_INT:return false
  if not is_finite(float(p[0])) or not is_finite(float(p[1])):return false
  if absf(float(p[0]))>6.0 or absf(float(p[1]))>250.0:return false
  if typeof(enemy.get("hp",null))!=TYPE_INT and typeof(enemy.get("hp",null))!=TYPE_FLOAT:return false
  if not is_finite(float(enemy["hp"])) or float(enemy["hp"])!=float(int(enemy["hp"])):return false
  # Each archetype has a different maximum HP. Reject edited/corrupt saves
  # that would restore enemies stronger than their authored combat stats.
  var max_enemy_hp: int=int([3,4,8,3,3,4][i])
  if int(enemy["hp"])<0 or int(enemy["hp"])>max_enemy_hp:return false
  if int(enemy["hp"])==0:dead+=1
 if dead!=int(data["kills"]):return false
 return true

static func write(data: Dictionary,path: String=SAVE_PATH) -> bool:
 if not validate(data):return false
 var tmp: String=path+".tmp"
 var file:=FileAccess.open(tmp,FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify(data))
 file.flush()
 var failed: bool=file.get_error()!=OK
 file.close()
 if failed:
  DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
  return false
 var result: Error=DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),ProjectSettings.globalize_path(path))
 if result!=OK:
  DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
  return false
 return true

static func read(path: String=SAVE_PATH) -> Dictionary:
 if not FileAccess.file_exists(path):return {}
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return {}
 # Reject oversized files before allocating their full contents in memory.
 # A damaged or hostile checkpoint must not stall a low-memory Android device.
 if file.get_length()>32768:
  file.close()
  return {}
 var raw: String=file.get_as_text()
 file.close()
 if raw.length()>32768:return {}
 var json:=JSON.new()
 if json.parse(raw)!=OK or not validate(json.data):return {}
 return json.data

static func clear(path: String=SAVE_PATH) -> void:
 if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 # A crashed/interrupted save can leave staging data behind; never treat it as
 # a checkpoint, and remove it when the player explicitly clears progress.
 var tmp: String=path+".tmp"
 if FileAccess.file_exists(tmp):DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
