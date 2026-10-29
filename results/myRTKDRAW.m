% rtk_analysis_plot.m
% 对 RESULTS_RTKFixed.txt 进行读取、RTK分析和可视化
% 被判为异常的点将**完全剔除**（不参与绘图与统计）。
% 增加了三维定位分布图（3D scatter）。
% 适用 MATLAB (不依赖额外 Toolboxes)。

%% 参数（如需修改）
fname = 'RESULTS_RTKFixed.txt';  % 文件名（或完整路径）
saveFigures = true;              % 是否把图保存为 PNG

%% 读取文件（跳过以 % 开头的注释）
fid = fopen(fname,'r');
if fid==-1
    error('无法打开文件: %s', fname);
end

data = {};
tline = fgetl(fid);
while ischar(tline)
    tline = strtrim(tline);
    if isempty(tline) || startsWith(tline,'%')
        tline = fgetl(fid);
        continue
    end
    parts = regexp(tline, '\s+', 'split');
    data(end+1,:) = parts; %#ok<SAGROW>
    tline = fgetl(fid);
end
fclose(fid);

% 将解析后的 cell -> 数组（根据已知列数）
N = size(data,1);
timeStr = cell(N,1);
lat = nan(N,1); lon = nan(N,1); h = nan(N,1);
Q = nan(N,1); ns = nan(N,1);
sdn = nan(N,1); sde = nan(N,1); sdu = nan(N,1);
sdne = nan(N,1); sdeu = nan(N,1); sdun = nan(N,1);
age = nan(N,1); ratio = nan(N,1); baseline = nan(N,1);

for i=1:N
    row = data(i,:);
    try
        datepart = row{1};
        timepart = row{2};
        timeStr{i} = [datepart ' ' timepart];
        lat(i) = str2double(row{3});
        lon(i) = str2double(row{4});
        h(i) = str2double(row{5});
        Q(i) = str2double(row{6});
        ns(i) = str2double(row{7});
        sdn(i) = str2double(row{8});
        sde(i) = str2double(row{9});
        sdu(i) = str2double(row{10});
        sdne(i) = str2double(row{11});
        sdeu(i) = str2double(row{12});
        sdun(i) = str2double(row{13});
        age(i) = str2double(row{14});
        ratio(i) = str2double(row{15});
        if numel(row) >= 16
            baseline(i) = str2double(row{16});
        end
    catch
        warning('解析第 %d 行失败，保持 NaN。', i);
    end
end

% 转换时间（含毫秒优先）
t = datetime(timeStr,'InputFormat','yyyy/MM/dd HH:mm:ss.SSS','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss');
nanTimeIdx = isnat(t);
if any(nanTimeIdx)
    t(nanTimeIdx) = datetime(timeStr(nanTimeIdx),'InputFormat','yyyy/MM/dd HH:mm:ss','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss');
end

%% 初始统计（raw）
total_points = N;
n_fix_raw = sum(Q==1);
n_float_raw = sum(Q==2);
fprintf('原始: 总点数=%d, FIX=%d, FLOAT=%d, FIX%%=%.2f%%\n', total_points, n_fix_raw, n_float_raw, 100*n_fix_raw/total_points);

%% 经纬度差 -> 局部 ENU (近似)
% 使用第一个有效点作为参考（若第一个是 NaN，找第一个非 NaN）
firstValid = find(~isnan(lat) & ~isnan(lon),1,'first');
if isempty(firstValid)
    error('没有有效的经纬度数据');
end
lat0 = lat(firstValid);
lon0 = lon(firstValid);
m_per_deg_lat = 111132.92 - 559.82*cosd(2*lat0) + 1.175*cosd(4*lat0) - 0.0023*cosd(6*lat0);
m_per_deg_lon = (pi/180) * 6378137 * cosd(lat0);
dlat = lat - lat0;
dlon = lon - lon0;
north = dlat * m_per_deg_lat;
east  = dlon * m_per_deg_lon;
enu_dist = sqrt(east.^2 + north.^2 + (h - h(firstValid)).^2);

%% 异常点剔除（完全剔除：不参与后续任何分析）
% 可调阈值（按需调小/调大）
max_delta_m = 0.5;      % 相邻点允许的最大位移（m）
max_delta_h = 0.7;      % 相邻点高度跳变阈值（m）
min_ratio = 3;          % ratio 小于此视为可信度低
max_sd = 5;             % sdn 或 sde 超过此值视为异常（m）
use_mad = true;         % 是否使用 MAD 检测极端离群点

% 计算相邻点差分（绝对值）
de = [0; abs(diff(east))];
dn = [0; abs(diff(north))];
dh = [0; abs(diff(h))];
d3 = sqrt(de.^2 + dn.^2 + dh.^2);

% 硬阈值判别
flag_delta = (de > max_delta_m) | (dn > max_delta_m) | (dh > max_delta_h) | (d3 > 1.0);
flag_ratio = (ratio < min_ratio) & ~isnan(ratio);
flag_sd = (sdn > max_sd) | (sde > max_sd);

% MAD 检测极端离群
flag_mad = false(size(d3));
if use_mad
    med = nanmedian(d3);
    madv = nanmedian(abs(d3 - med));
    if madv == 0, madv = eps; end
    flag_mad = abs(d3 - med) > (6 * madv);
end

% 合并标志，第一点保留（除非为 NaN）
flag = flag_delta | flag_ratio | flag_sd | flag_mad;
flag(1) = false;

% 最终保留索引（同时排除经/纬 NaN）
keep = ~flag & ~isnan(lat) & ~isnan(lon);

% 报告
n_removed = sum(~keep);
fprintf('剔除异常点: %d / %d (%.2f%%)\n', n_removed, total_points, 100*n_removed/total_points);

% 用清理后的数据替换原变量（后续全部基于这些变量）
lat = lat(keep);
lon = lon(keep);
h = h(keep);
t = t(keep);
Q = Q(keep);
ns = ns(keep);
sdn = sdn(keep);
sde = sde(keep);
sdu = sdu(keep);
sdne = sdne(keep);
sdeu = sdeu(keep);
sdun = sdun(keep);
age = age(keep);
ratio = ratio(keep);
baseline = baseline(keep);
east = east(keep);
north = north(keep);
enu_dist = enu_dist(keep);

%% 清理后统计与绘图（所有分析仅用清理后数据）
total_points_clean = length(lat);
n_fix = sum(Q==1);
n_float = sum(Q==2);
pct_fix = 100 * n_fix / total_points_clean;

fprintf('清理后: 总点数=%d, FIX=%d, FLOAT=%d, FIX%%=%.2f%%\n', total_points_clean, n_fix, n_float, pct_fix);
fprintf('ratio : mean=%.2f median=%.2f std=%.2f\n', nanmean(ratio), nanmedian(ratio), nanstd(ratio));
fprintf('baseline : min=%.3f max=%.3f mean=%.3f\n', nanmin(baseline), nanmax(baseline), nanmean(baseline));

% 绘图 1: 轨迹（经度 vs 纬度）
figure('Name','Trajectory LAT-LON ');
hold on;
idxFix = (Q==1);
idxFloat = (Q==2);
if any(idxFloat), scatter(lon(idxFloat), lat(idxFloat), 12, 'filled', 'MarkerFaceAlpha',0.5); end
if any(idxFix), scatter(lon(idxFix), lat(idxFix), 18, 'r', 'filled'); end
plot(lon, lat, '-k', 'LineWidth', 0.8);
xlabel('Longitude (deg)'); ylabel('Latitude (deg)');
title('Trajectory (lon vs lat) — red=FIX ');
legend({'FLOAT','FIX','path'}, 'Location','best');
axis equal; grid on;
if saveFigures, saveas(gcf,'trajectory_lat_lon.png'); end

% 绘图 2: ENU XY 散点（以米）
figure('Name','ENU East-North (m) ');
scatter(east, north, 8, ratio, 'filled'); colorbar; hold on;
if any(idxFix), scatter(east(idxFix), north(idxFix), 20, 'r','filled'); end
xlabel('East (m)'); ylabel('North (m)');
title('Local ENU offsets (colored by ratio) '); grid on; axis equal;
if saveFigures, saveas(gcf,'enu_xy.png'); end

% 绘图 3: 经度/纬度/高随时间
figure('Name','Lat Lon Height vs Time ');
subplot(3,1,1);
plot(t, lat); ylabel('Latitude (deg)'); grid on;
subplot(3,1,2);
plot(t, lon); ylabel('Longitude (deg)'); grid on;
subplot(3,1,3);
plot(t, h); ylabel('Height (m)'); datetick('x','keeplimits'); grid on;
xlabel('Time (UTC)');
if saveFigures, saveas(gcf,'lat_lon_h_time.png'); end

% 绘图 4: ratio & baseline vs time
figure('Name','ratio & baseline vs time');
yyaxis left
plot(t, ratio, '-b'); ylabel('ratio');
yyaxis right
plot(t, baseline, '-r'); ylabel('baseline (m)');
xlabel('Time (UTC)'); title('RTK ratio (left) and baseline (right)'); grid on;
if saveFigures, saveas(gcf,'ratio_baseline_time.png'); end

% 绘图 5: sdn,sde,sdu (精度) 和 水平/3D RMS
hdop = sqrt(sdn.^2 + sde.^2);
rms3d = sqrt(sdn.^2 + sde.^2 + sdu.^2);
figure('Name','Precision (sdn,sde,sdu) & RMS ');
plot(t, sdn, '-r'); hold on; plot(t, sde, '-g'); plot(t, sdu, '-b');
plot(t, hdop, '--k','LineWidth',1);
legend({'sdn','sde','sdu','horizontal RMS est.'}, 'Location','best');
xlabel('Time (UTC)'); ylabel('meters'); grid on;
if saveFigures, saveas(gcf,'sd_components.png'); end

% 绘图 6: height histogram
figure('Name','Height histogram ');
histogram(h, 40);
xlabel('Height (m)'); ylabel('count'); title('Height distribution');
if saveFigures, saveas(gcf,'height_hist.png'); end

% 新增 绘图 7: 三维定位分布（ENU East, North, Height）
figure('Name','3D Position Distribution');
% 使用 ratio 着色（可改为 Q 着色）
scatter3(east, north, h, 24, ratio, 'filled');
xlabel('East (m)'); ylabel('North (m)'); zlabel('Height (m)');
title('3D Position Distribution  - colored by ratio');
colorbar;
view(45,25); grid on;
% 使三轴尺度更接近（如果高度范围与平面范围差异大，可调整）
try
    daspect([1 1 0.5]);
catch
    % 如果 daspect 不生效则忽略
end
if saveFigures, saveas(gcf,'3d_position_distribution.png'); end

% 详细统计输出（cleaned）
fprintf('\n--- RTK 详细统计  ---\n');
fprintf('Height : mean=%.3f m, std=%.3f m, min=%.3f, max=%.3f\n', nanmean(h), nanstd(h), nanmin(h), nanmax(h));
fprintf('Horizontal RMS (mean) = %.4f m\n', nanmean(hdop));
fprintf('3D RMS (mean) = %.4f m\n', nanmean(rms3d));

% ratio 分段统计（cleaned）
r_bins = [0 1 2 3 4 5 10 20 100];
for i=1:length(r_bins)-1
    idx = ratio >= r_bins(i) & ratio < r_bins(i+1);
    if any(idx)
        fprintf(' ratio in [%g,%g): count=%d, pct=%.2f%%\n', r_bins(i), r_bins(i+1), sum(idx), 100*sum(idx)/total_points_clean);
    end
end

% Sliding FIX% (cleaned)
winSec = 60;
tvec_c = t(1):seconds(5):t(end);
fix_pct_time_c = nan(size(tvec_c));
for i=1:length(tvec_c)
    wstart = tvec_c(i) - seconds(winSec/2);
    wend = tvec_c(i) + seconds(winSec/2);
    idxw = t >= wstart & t <= wend;
    if any(idxw)
        fix_pct_time_c(i) = 100*sum(Q(idxw)==1)/sum(idxw);
    end
end
figure('Name','Sliding FIX% ');
plot(tvec_c, fix_pct_time_c, '-','LineWidth',1.2);
xlabel('Time (UTC)'); ylabel('FIX % (window 60 s)'); grid on;
if saveFigures, saveas(gcf,'fix_pct_time.png'); end

horizontal_error = sqrt(sdn.^2 + sde.^2);  % 计算水平误差

figure('Name','Horizontal Error ');
plot(t, horizontal_error, '-b', 'LineWidth', 1.2);
xlabel('Time (UTC)'); ylabel('Horizontal Error (m)');
title('Horizontal Error ');
grid on;

if saveFigures
    saveas(gcf,'horizontal_error.png');
end

fprintf('\n所有图均基于已清理的数据（剔除点不参与任何分析与绘图）。\n');
