package com.dongjiayi.mxloggerdemo;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.dongjiayi.mxlogger.MXLogger;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/** 日志查看器: 演示 selectWithFilePath 解析日志文件 支持等级筛选与搜索 */
public class LogViewerActivity extends AppCompatActivity {

    private static final String[] CHIP_TITLES = {"全部", "Debug", "Info", "Warn", "Error", "Fatal"};

    private final List<JSONObject> allRecords = new ArrayList<>();
    private final List<JSONObject> filteredRecords = new ArrayList<>();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private RecordAdapter adapter;
    private LinearLayout levelChips;
    private View loadingView;
    private TextView emptyLabel;
    private EditText searchInput;
    private Toolbar toolbar;

    private int selectedLevelChip = 0;
    private String fileName;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_log_viewer);

        fileName = getIntent().getStringExtra("fileName");

        toolbar = findViewById(R.id.toolbar);
        toolbar.setTitle(fileName == null ? "日志详情" : fileName);
        toolbar.setNavigationOnClickListener(v -> finish());

        levelChips = findViewById(R.id.levelChips);
        loadingView = findViewById(R.id.loadingView);
        emptyLabel = findViewById(R.id.emptyLabel);
        searchInput = findViewById(R.id.searchInput);

        RecyclerView recycler = findViewById(R.id.recycler);
        recycler.setClipToOutline(true);
        recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new RecordAdapter();
        recycler.setAdapter(adapter);

        buildChips();
        searchInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                applyFilter();
            }

            @Override
            public void afterTextChanged(Editable s) {
            }
        });

        loadRecords();
    }

    private void buildChips() {
        for (int i = 0; i < CHIP_TITLES.length; i++) {
            final int index = i;
            TextView chip = new TextView(this);
            chip.setText(CHIP_TITLES[i]);
            chip.setTextSize(13);
            chip.setPadding(dp(14), dp(6), dp(14), dp(6));
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            if (i > 0) params.setMarginStart(dp(8));
            chip.setOnClickListener(v -> {
                selectedLevelChip = index;
                restyleChips();
                applyFilter();
            });
            levelChips.addView(chip, params);
        }
        restyleChips();
    }

    private void restyleChips() {
        for (int i = 0; i < levelChips.getChildCount(); i++) {
            TextView chip = (TextView) levelChips.getChildAt(i);
            boolean selected = i == selectedLevelChip;
            chip.setBackgroundResource(selected ? R.drawable.bg_chip_selected : R.drawable.bg_chip);
            chip.setTextColor(ContextCompat.getColor(this,
                    selected ? R.color.white : R.color.text_secondary));
        }
    }

    private void loadRecords() {
        // 大文件解析可能耗时较长 解析期间展示 loading 解析放在后台线程避免卡 UI
        loadingView.setVisibility(View.VISIBLE);
        emptyLabel.setVisibility(View.GONE);

        final String filePath = getIntent().getStringExtra("filePath");
        final String cryptKey = getIntent().getStringExtra("cryptKey");
        final String iv = getIntent().getStringExtra("iv");

        new Thread(() -> {
            // 解析(解密) mmap 日志文件 返回最新在前
            // 字段: name/msg/tag/level/timestamp/is_main_thread/thread_id/error_code
            String[] array = MXLogger.selectWithFilePath(filePath, cryptKey, iv);
            final List<JSONObject> records = new ArrayList<>();
            if (array != null) {
                for (String json : array) {
                    try {
                        records.add(new JSONObject(json));
                    } catch (Exception ignored) {
                    }
                }
            }
            mainHandler.post(() -> {
                allRecords.clear();
                allRecords.addAll(records);
                loadingView.setVisibility(View.GONE);
                if (fileName != null) {
                    toolbar.setTitle(String.format(Locale.US, "%s (%d)", fileName, records.size()));
                }
                applyFilter();
            });
        }).start();
    }

    private void applyFilter() {
        String keyword = searchInput.getText() == null ? "" : searchInput.getText().toString().trim().toLowerCase(Locale.US);
        filteredRecords.clear();
        for (JSONObject record : allRecords) {
            if (selectedLevelChip > 0 && record.optInt("level", -1) != selectedLevelChip - 1) continue;
            if (keyword.length() > 0) {
                String haystack = (record.optString("msg") + " " + record.optString("name") + " "
                        + record.optString("tag")).toLowerCase(Locale.US);
                if (!haystack.contains(keyword)) continue;
            }
            filteredRecords.add(record);
        }
        emptyLabel.setVisibility(filteredRecords.isEmpty() && loadingView.getVisibility() != View.VISIBLE
                ? View.VISIBLE : View.GONE);
        adapter.notifyDataSetChanged();
    }

    private void showDetail(JSONObject record) {
        String name = record.optString("name");
        final String msg = record.optString("msg");
        new AlertDialog.Builder(this)
                .setTitle(name.length() > 0 ? name : "日志详情")
                .setMessage(msg)
                .setPositiveButton("复制", (dialog, which) -> {
                    ClipboardManager manager = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                    manager.setPrimaryClip(ClipData.newPlainText("mxlogger", msg));
                })
                .setNegativeButton("关闭", null)
                .show();
    }

    private int dp(int value) {
        return Math.round(getResources().getDisplayMetrics().density * value);
    }

    private class RecordAdapter extends RecyclerView.Adapter<RecordHolder> {

        @NonNull
        @Override
        public RecordHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            return new RecordHolder(LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_log_record, parent, false));
        }

        @Override
        public void onBindViewHolder(@NonNull RecordHolder holder, int position) {
            JSONObject record = filteredRecords.get(position);
            int level = record.optInt("level", 0);
            boolean parseFailed = record.optInt("error_code", 0) != 0;

            if (parseFailed) {
                holder.badge.setText("BAD");
                holder.badge.getBackground().mutate().setTint(
                        ContextCompat.getColor(LogViewerActivity.this, R.color.level_error));
            } else {
                int index = (level >= 0 && level < DemoUtil.LEVEL_BADGES.length) ? level : 0;
                holder.badge.setText(DemoUtil.LEVEL_BADGES[index]);
                holder.badge.getBackground().mutate().setTint(
                        ContextCompat.getColor(LogViewerActivity.this, DemoUtil.LEVEL_COLORS[index]));
            }

            String name = record.optString("name");
            holder.name.setText(name.length() > 0 ? name : "-");
            holder.time.setText(DemoUtil.dateText(record.optString("timestamp"), "MM-dd HH:mm:ss.SSS"));
            holder.msg.setText(parseFailed ? "数据解析失败: " + record.optString("msg") : record.optString("msg"));

            String tag = record.optString("tag");
            holder.tagChip.setVisibility(tag.length() > 0 ? View.VISIBLE : View.GONE);
            holder.tagChip.setText("# " + tag);

            boolean isMain = "1".equals(record.optString("is_main_thread"))
                    || "true".equals(record.optString("is_main_thread"));
            holder.thread.setText(String.format(Locale.US, "%s · tid %s",
                    isMain ? "主线程" : "子线程", record.optString("thread_id", "-")));

            holder.itemView.setOnClickListener(v -> showDetail(record));
        }

        @Override
        public int getItemCount() {
            return filteredRecords.size();
        }
    }

    private static class RecordHolder extends RecyclerView.ViewHolder {
        final TextView badge, name, time, msg, tagChip, thread;

        RecordHolder(@NonNull View itemView) {
            super(itemView);
            badge = itemView.findViewById(R.id.badge);
            name = itemView.findViewById(R.id.name);
            time = itemView.findViewById(R.id.time);
            msg = itemView.findViewById(R.id.msg);
            tagChip = itemView.findViewById(R.id.tagChip);
            thread = itemView.findViewById(R.id.thread);
        }
    }
}
