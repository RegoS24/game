package com.blacksignal.rin;
import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.view.WindowManager;
import android.os.Build;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;
public class MainActivity extends Activity {
 private WebView game;
 @Override public void onCreate(Bundle saved) {
 super.onCreate(saved);getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,WindowManager.LayoutParams.FLAG_FULLSCREEN);if(Build.VERSION.SDK_INT>=28){WindowManager.LayoutParams lp=getWindow().getAttributes();lp.layoutInDisplayCutoutMode=WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;getWindow().setAttributes(lp);}getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON); immersive();
 game=new WebView(this);game.setBackgroundColor(0xff081018);WebSettings s=game.getSettings();s.setJavaScriptEnabled(true);s.setUseWideViewPort(true);s.setLoadWithOverviewMode(false);game.setOverScrollMode(View.OVER_SCROLL_NEVER);game.setHorizontalScrollBarEnabled(false);game.setVerticalScrollBarEnabled(false);s.setDomStorageEnabled(true);s.setMediaPlaybackRequiresUserGesture(true);s.setAllowFileAccess(false);s.setAllowContentAccess(false);s.setBlockNetworkLoads(true);game.setWebViewClient(new WebViewClient());setContentView(game);immersive();game.loadUrl("file:///android_asset/index.html");
 }
 private void immersive(){if(Build.VERSION.SDK_INT>=30){getWindow().setDecorFitsSystemWindows(false);WindowInsetsController c=getWindow().getInsetsController();if(c!=null){c.hide(WindowInsets.Type.systemBars());c.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);}}getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN|View.SYSTEM_UI_FLAG_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_LAYOUT_STABLE);}
 @Override public void onWindowFocusChanged(boolean focus){super.onWindowFocusChanged(focus);if(focus)immersive();}
 @Override protected void onPause(){super.onPause();if(game!=null){game.evaluateJavascript("if(typeof save==='function')save()",null);game.onPause();}}
 @Override protected void onResume(){super.onResume();if(game!=null)game.onResume();immersive();}
 @Override public void onBackPressed(){if(game!=null)game.evaluateJavascript("if(typeof game!=='undefined'&&game){if(activePanel)closeMenu();else if(!paused)menu('pause')}",null);}
 @Override protected void onDestroy(){if(game!=null){game.destroy();game=null;}super.onDestroy();}
}