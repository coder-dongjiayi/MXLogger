package com.dongjiayi.mxloggerdemo;

import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import androidx.navigation.fragment.NavHostFragment;

import com.dongjiayi.mxlogger.MXLogger;
import com.dongjiayi.mxloggerdemo.databinding.FragmentFirstBinding;

public class FirstFragment extends Fragment {

    private FragmentFirstBinding binding;
    private  MXLogger logger;
    @Override
    public View onCreateView(
            LayoutInflater inflater, ViewGroup container,
            Bundle savedInstanceState
    ) {

        logger = new MXLogger(this.getContext(),"com.dongjiayi.mxlogger");
        logger.consoleEnable = false;
        logger.maxDiskAge = 10;
        logger.debug("request","mxlogger","this is debug");
        logger.info("request","mxlogger","this is info");
        logger.warn("request","mxlogger","this is warn");
        logger.error("request","mxlogger","this is error");
        logger.fatal("request","mxlogger","this is fatal");

        binding = FragmentFirstBinding.inflate(inflater, container, false);
        return binding.getRoot();

    }

    public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        binding.buttonFirst.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Log.i("begin","开始写入");
                for (int i=0;i<100000;i++){
                    logger.log("net",0,"android","this is message");
                }

                Log.i("end","结束写入");
            }
        });
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }

}