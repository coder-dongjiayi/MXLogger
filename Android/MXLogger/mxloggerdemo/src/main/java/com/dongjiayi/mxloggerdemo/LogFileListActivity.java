package com.dongjiayi.mxloggerdemo;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.dongjiayi.mxlogger.MXLogger;

import org.json.JSONObject;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/** 日志文件列表: 演示 logFiles API */
public class LogFileListActivity extends AppCompatActivity {

    private final List<JSONObject> files = new ArrayList<>();
    private FileAdapter adapter;
    private TextView summary, emptyLabel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_file_list);

        Toolbar toolbar = findViewById(R.id.toolbar);
        toolbar.setNavigationOnClickListener(v -> finish());

        summary = findViewById(R.id.summary);
        emptyLabel = findViewById(R.id.emptyLabel);
        RecyclerView recycler = findViewById(R.id.recycler);
        recycler.setClipToOutline(true);
        recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new FileAdapter();
        recycler.setAdapter(adapter);
    }

    @Override
    protected void onResume() {
        super.onResume();
        reloadFiles();
    }

    private void reloadFiles() {
        files.clear();
        MXLogger logger = DemoHomeActivity.sharedLogger;
        long totalSize = 0;
        if (logger != null) {
            String[] array = logger.logFiles();
            if (array != null) {
                for (String json : array) {
                    try {
                        JSONObject file = new JSONObject(json);
                        files.add(file);
                        totalSize += file.optLong("size", 0);
                    } catch (Exception ignored) {
                    }
                }
            }
        }
        // 按最后更新时间倒序 最新的文件排在最上面
        Collections.sort(files, (a, b) ->
                Double.compare(b.optDouble("last_timestamp", 0), a.optDouble("last_timestamp", 0)));

        summary.setText(String.format(Locale.US, "共 %d 个文件 · 总大小 %s", files.size(), DemoUtil.byteText(totalSize)));
        emptyLabel.setVisibility(files.isEmpty() ? View.VISIBLE : View.GONE);
        adapter.notifyDataSetChanged();
    }

    private class FileAdapter extends RecyclerView.Adapter<FileHolder> {

        @NonNull
        @Override
        public FileHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            return new FileHolder(LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_log_file, parent, false));
        }

        @Override
        public void onBindViewHolder(@NonNull FileHolder holder, int position) {
            JSONObject file = files.get(position);
            String name = file.optString("name");
            holder.name.setText(name);
            holder.dates.setText(String.format(Locale.US, "创建 %s · 更新 %s",
                    DemoUtil.dateText(file.optString("create_timestamp"), "MM-dd HH:mm:ss"),
                    DemoUtil.dateText(file.optString("last_timestamp"), "MM-dd HH:mm:ss")));
            holder.size.setText(DemoUtil.byteText(file.optLong("size", 0)));
            holder.itemView.setOnClickListener(v -> {
                MXLogger logger = DemoHomeActivity.sharedLogger;
                if (logger == null) return;
                Intent intent = new Intent(LogFileListActivity.this, LogViewerActivity.class);
                intent.putExtra("filePath", new File(logger.getDiskCachePath(), name).getAbsolutePath());
                intent.putExtra("fileName", name);
                intent.putExtra("cryptKey", DemoHomeActivity.CRYPT_KEY);
                intent.putExtra("iv", DemoHomeActivity.IV);
                startActivity(intent);
            });
        }

        @Override
        public int getItemCount() {
            return files.size();
        }
    }

    private static class FileHolder extends RecyclerView.ViewHolder {
        final TextView name, dates, size;

        FileHolder(@NonNull View itemView) {
            super(itemView);
            name = itemView.findViewById(R.id.name);
            dates = itemView.findViewById(R.id.dates);
            size = itemView.findViewById(R.id.size);
        }
    }
}
