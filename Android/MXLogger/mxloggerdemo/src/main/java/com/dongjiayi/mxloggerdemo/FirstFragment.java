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

        /// android端需要自己进行监听程序进入后台和杀死的 从而调用 removeExpireData() 方法清理日志数据
        logger =   MXLogger.initWithNamespace(this.getContext(),"javamxlogger");

        logger.info("path",logger.getDiskCachePath());

        logger.setMaxDiskSize(1024*1024*10);
        logger.setMaxDiskAge(60*60*24*7);
        /// 以下都是默认设置
        logger.setStoragePolicy("yyyy_MM_dd");
        logger.setFileName("mxlog");
        logger.setConsoleLevel(0);
        logger.setFileLevel(1);
        logger.setConsolePattern("[%d][%p]%m");
        logger.setFilePattern("[%d][%t][%p]%m");

        binding = FragmentFirstBinding.inflate(inflater, container, false);
        return binding.getRoot();

    }

    public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        binding.buttonFirst.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {

                logger.debug("tag","这是一条debug信息");
                logger.info("tag","这是一条info信息");
                logger.warn("tag","这是一条warn信息");
                logger.error("tag","这是一条error信息");
                logger.fatal("tag","这是一条fatal信息");

            }
        });
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }

}