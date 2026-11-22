extends RefCounted
## Chapter 01 gameplay logic; pure state machine independent of rendering.
enum Phase { SCAN, ELIMINATE, EXTRACT, COMPLETE }
const TERMINAL: Vector2=Vector2(-2.0,31.0)
const EXFIL: Vector2=Vector2(0.0,141.0)
const INTERACTION_RANGE: float=2.7
const REQUIRED_KILLS: int=6
const SAVE_PATH: String="user://black_signal_chapter01.cfg"
var phase: int=Phase.SCAN
var best_seconds: float=-1.0
var completed_runs: int=0
var mission_elapsed: float=0.0

func begin() -> void:
 phase=Phase.SCAN
 mission_elapsed=0.0

func load_record() -> void:
 # Reset in-memory records even when the file is missing or unreadable.
 # Otherwise a failed reload can leave stale progress from a previous session.
 best_seconds=-1.0
 completed_runs=0
 var cfg:=ConfigFile.new()
 if cfg.load(SAVE_PATH)!=OK:return
 # Treat the record as untrusted: corrupt or edited ConfigFile values must not
 # become NaN/Infinity, negative counts, or invalid numeric conversions.
 var raw_best: Variant=cfg.get_value("chapter01","best_seconds",-1.0)
 var raw_runs: Variant=cfg.get_value("chapter01","completed_runs",0)
 if typeof(raw_best)==TYPE_FLOAT or typeof(raw_best)==TYPE_INT:
  var candidate: float=float(raw_best)
  if is_finite(candidate) and candidate>=0.0:best_seconds=candidate
 if typeof(raw_runs)==TYPE_INT:
  if raw_runs>=0 and raw_runs<2147483647:completed_runs=int(raw_runs)

func save_record() -> bool:
 var cfg:=ConfigFile.new()
 cfg.set_value("chapter01","best_seconds",best_seconds)
 cfg.set_value("chapter01","completed_runs",completed_runs)
 return cfg.save(SAVE_PATH)==OK

func has_marker() -> bool:
 return phase==Phase.SCAN or phase==Phase.EXTRACT

func marker_position() -> Vector2:
 return EXFIL if phase==Phase.EXTRACT else TERMINAL

func in_range(player: Vector2) -> bool:
 return has_marker() and player.distance_to(marker_position())<=INTERACTION_RANGE

func register_kills(count: int) -> bool:
 if phase==Phase.ELIMINATE and count>=REQUIRED_KILLS:
  phase=Phase.EXTRACT
  return true
 return false

func interact(player: Vector2,kills: int,elapsed: float,persist: bool=true) -> String:
 if not in_range(player):return ""
 # Reject invalid completion times before mutating the campaign record.
 if phase==Phase.EXTRACT and (not is_finite(elapsed) or elapsed<0.0):return ""
 if phase==Phase.SCAN:
  phase=Phase.ELIMINATE
  if kills>=REQUIRED_KILLS:phase=Phase.EXTRACT
  return "ДАННЫЕ СИГНАЛА ПОЛУЧЕНЫ"
 if phase==Phase.EXTRACT and kills>=REQUIRED_KILLS:
  phase=Phase.COMPLETE
  mission_elapsed=maxf(0.0,elapsed)
  completed_runs=mini(completed_runs+1,2147483646)
  if best_seconds<0.0 or mission_elapsed<best_seconds:best_seconds=mission_elapsed
  if persist and not save_record():return "ЭВАКУАЦИЯ ВЫПОЛНЕНА — ПРОГРЕСС НЕ СОХРАНЁН"
  return "МИССИЯ ЗАВЕРШЕНА"
 return ""

func objective_text(kills: int) -> String:
 match phase:
  Phase.SCAN:return "01  /  СКАЧАТЬ ДАННЫЕ С ТЕРМИНАЛА"
  Phase.ELIMINATE:return "02  /  ЗАЧИСТИТЬ СЕКТОР  %d / %d"%[kills,REQUIRED_KILLS]
  Phase.EXTRACT:return "03  /  ДОБРАТЬСЯ ДО ЭВАКУАЦИИ"
  _:return "МИССИЯ ЗАВЕРШЕНА"
