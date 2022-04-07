package com.dongjiayi.mxloggerdemo;

import android.os.Bundle;

import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AppCompatActivity;

import android.view.View;

import androidx.navigation.NavController;
import androidx.navigation.Navigation;
import androidx.navigation.ui.AppBarConfiguration;
import androidx.navigation.ui.NavigationUI;

import com.dongjiayi.mxloggerdemo.databinding.ActivityMainBinding;

import android.view.Menu;
import android.view.MenuItem;
import com.dongjiayi.mxlogger.MXLogger;
public class MainActivity extends AppCompatActivity {

    private AppBarConfiguration appBarConfiguration;
    private ActivityMainBinding binding;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);


        // 初始化日志目录
        MXLogger.initialize(MainActivity.this);


        MXLogger.setFileName("customName");
        MXLogger.setFileHeader("平台:android");
        MXLogger.setMaxDiskAge(60 * 60 * 24 * 7);
        MXLogger.setMaxDiskSize(1024 * 1024 * 100);

        MXLogger.setStoragePolicy("yyyy_MM_dd_HH");
        MXLogger.setConsolePattern("[%d][%p]%m");
        MXLogger.setFilePattern("[%d][%t][%p]%m");

        MXLogger.setConsoleLevel(0);
        MXLogger.setFileLevel(1);

        MXLogger.setConsoleEnable(true);
        MXLogger.setFileEnable(true);


        MXLogger.debug("当前日志大小:" + Long.toString(MXLogger.getLogSize()));



        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        setSupportActionBar(binding.toolbar);

        NavController navController = Navigation.findNavController(this, R.id.nav_host_fragment_content_main);
        appBarConfiguration = new AppBarConfiguration.Builder(navController.getGraph()).build();
        NavigationUI.setupActionBarWithNavController(this, navController, appBarConfiguration);

        binding.fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Snackbar.make(view, "Replace with your own action", Snackbar.LENGTH_LONG)
                        .setAction("Action", null).show();
            }
        });
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }

    @Override
    public boolean onSupportNavigateUp() {
        NavController navController = Navigation.findNavController(this, R.id.nav_host_fragment_content_main);
        return NavigationUI.navigateUp(navController, appBarConfiguration)
                || super.onSupportNavigateUp();
    }
}