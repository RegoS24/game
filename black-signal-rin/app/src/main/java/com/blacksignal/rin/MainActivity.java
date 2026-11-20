package com.blacksignal.rin;
import android.app.Activity;
import android.app.AlertDialog;
import android.os.Bundle;
import android.os.Build;
import android.view.View;
import android.view.WindowManager;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.*;
import android.graphics.Color;
import android.net.Uri;
import android.content.Intent;
import android.util.Log;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Button;

public class MainActivity extends Activity {
 private static final String TAG="BlackSignal";
 private static final String URL="file:///android_asset/index.html";
 private WebView game;
 private boolean smoke=false, fallback=false;
 @Override public void onCreate(Bundle saved) {
  super.onCreate(saved);
  smoke="1".equals(getIntent().getStringExtra("smoke")) && (Build.FINGERPRINT.contains("generic") || Build.MODEL.contains("sdk_gphone") || Build.HARDWARE.contains("ranchu"));
  getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON|WindowManager.LayoutParams.FLAG_FULLSCREEN);
  if(Build.VERSION.SDK_INT>=28){WindowManager.LayoutParams lp=getWindow().getAttributes();lp.layoutInDisplayCutoutMode=WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;getWindow().setAttributes(lp);}
  try {
   game=new WebView(this);
   game.setBackgroundColor(0xff081018);
   game.setOverScrollMode(View.OVER_SCROLL_NEVER);
   game.setHorizontalScrollBarEnabled(false);
   game.setVerticalScrollBarEnabled(false);
   WebSettings s=game.getSettings();
   s.setJavaScriptEnabled(true);s.setDomStorageEnabled(true);s.setUseWideViewPort(true);s.setLoadWithOverviewMode(false);
   s.setMediaPlaybackRequiresUserGesture(true);s.setAllowFileAccess(false);s.setAllowContentAccess(false);s.setBlockNetworkLoads(true);
   game.setWebChromeClient(new WebChromeClient(){
    @Override public boolean onConsoleMessage(ConsoleMessage message){Log.i(TAG,"JS "+message.messageLevel()+": "+message.message()+" (line "+message.lineNumber()+")");return true;}
   });
   game.setWebViewClient(new WebViewClient(){
    @Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest request){return !URL.equals(request.getUrl().toString());}
    @Override public void onReceivedError(WebView view,WebResourceRequest request,WebResourceError error){
     if(request.isForMainFrame()){Log.e(TAG,"WEB_LOAD_ERROR "+error.getDescription());if(!fallback){fallback=true;loadBackup();}else showFailure("Не удалось открыть игровые файлы: "+error.getDescription());}
    }
    @Override public void onPageFinished(WebView view,String url){
     view.postDelayed(()->checkReady(view),450);
    }
    @Override public boolean onRenderProcessGone(WebView view,RenderProcessGoneDetail detail){
     Log.e(TAG,"WEB_RENDER_GONE");game=null;view.destroy();showFailure("Графический процесс Android WebView остановлен. Обнови Android System WebView и повтори запуск.");return true;
    }
   });
   setContentView(game);immersive();game.loadUrl(URL);
  } catch(Exception e){Log.e(TAG,"NATIVE_START_ERROR",e);showFailure("Не удалось запустить Android WebView. Проверь, что Android System WebView включён и обновлён.");}
 }
 private void loadBackup(){
  try(java.io.InputStream in=getAssets().open("index.html");java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream()){
   byte[] buf=new byte[8192];int n;while((n=in.read(buf))!=-1)out.write(buf,0,n);
   game.loadDataWithBaseURL(URL,out.toString("UTF-8"),"text/html","UTF-8",null);
  }catch(Exception e){Log.e(TAG,"ASSET_READ_ERROR",e);showFailure("Игровой файл не найден или повреждён.");}
 }
 private void checkReady(WebView view){
  if(game!=view||isFinishing())return;
  view.evaluateJavascript("(typeof start==='function' && typeof render==='function' && typeof tac!=='undefined' && typeof heroes!=='undefined' && document.getElementById('new')!==null && document.readyState==='complete')", value->{
   if(!"true".equals(value)){Log.e(TAG,"JS_START_ERROR "+value);showFailure("Игровой код не запустился. Обнови Android System WebView. Если ошибка повторяется, сообщи версию Android.");return;}
   Log.i(TAG,"GAME_READY");
   if(smoke)view.evaluateJavascript("(function(){try{start(!!load());var b=document.querySelector('#dialogChoices button');if(b)b.click();requestAnimationFrame(function(){try{render(performance.now());console.log(game && !paused && S.slots && S.hero ? 'BS_SMOKE_OK' : 'BS_SMOKE_STATE_FAIL');}catch(e){console.error('BS_SMOKE_RENDER '+e.message);}});return true}catch(e){console.error('BS_SMOKE_INIT '+e.message);return false}})()",null);
  });
 }
 private void showFailure(String reason){
  runOnUiThread(()->{LinearLayout layout=new LinearLayout(this);layout.setOrientation(LinearLayout.VERTICAL);layout.setPadding(40,24,40,24);layout.setBackgroundColor(0xff101923);TextView msg=new TextView(this);msg.setText("BLACK SIGNAL\n\n"+reason);msg.setTextSize(18);msg.setTextColor(Color.WHITE);layout.addView(msg);Button retry=new Button(this);retry.setText("Повторить запуск");retry.setOnClickListener(v->recreate());layout.addView(retry);Button update=new Button(this);update.setText("Настройки приложений");update.setOnClickListener(v->{try{startActivity(new Intent(android.provider.Settings.ACTION_APPLICATION_SETTINGS));}catch(Exception ignored){}});layout.addView(update);setContentView(layout);immersive();});
 }
 private void immersive(){if(Build.VERSION.SDK_INT>=30){getWindow().setDecorFitsSystemWindows(false);WindowInsetsController c=getWindow().getInsetsController();if(c!=null){c.hide(WindowInsets.Type.systemBars());c.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);}}getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN|View.SYSTEM_UI_FLAG_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_LAYOUT_STABLE);}
 @Override public void onWindowFocusChanged(boolean focus){super.onWindowFocusChanged(focus);if(focus)immersive();}
 @Override protected void onPause(){if(game!=null){game.evaluateJavascript("if(typeof save==='function')save()",null);game.onPause();}super.onPause();}
 @Override protected void onResume(){super.onResume();if(game!=null)game.onResume();immersive();}
 @Override public void onBackPressed(){if(game!=null)game.evaluateJavascript("if(typeof game!=='undefined'&&game){if(activePanel)closeMenu();else if(!paused)menu('pause')}",null);else super.onBackPressed();}
 @Override protected void onDestroy(){if(game!=null){game.destroy();game=null;}super.onDestroy();}
}