# Phim KKPhim trên Rofi

`rofi.movie` là phần xem phim của **anisub** (`src/movie/kkphim.sh`) được
chuyển sang khung Rofi của HyDE/AniDE. Thay vì dùng `fzf` và xem trước poster
bằng `chafa`, mọi bước được trình bày thành các menu `rofi -dmenu` nối tiếp
nhau: tìm kiếm, duyệt danh mục, chọn nguồn, chọn tập rồi phát.

Dữ liệu lấy từ API công khai của KKPhim (`https://phimapi.com`), đúng nguồn mà
module anisub sử dụng:

- `/v1/api/tim-kiem?keyword=` — tìm kiếm (từ 2 ký tự).
- `/v1/api/danh-sach/{danh-muc}` — danh mục, có lọc `category` và `country`.
- `/phim/{slug}` — chi tiết phim, kèm link HLS (m3u8) của từng tập.

Link m3u8 của KKPhim hết hạn sau vài phút, nên chi tiết phim chỉ được cache
ngắn hạn và được tải lại mỗi lần bắt đầu phát.

## Mở bằng phím tắt

```txt
SUPER + SHIFT + M   # mở thẳng menu phim
SUPER + A           # application finder: gõ "AniSub", "phim" hoặc "kkphim"
```

Hoặc chạy trực tiếp:

```sh
hyde-shell rofi.movie
```

AniSub cũng nằm trong menu **SUPER + A** nhờ `anide-movie.desktop`
(`Exec=hyde-shell rofi.movie`), nên không cần nhớ phím tắt riêng.

Menu chính gồm **Tìm phim**, **Duyệt danh mục**, **Phim mới cập nhật**,
**Tiếp tục xem**, **Lịch sử xem**, **Cài đặt** và **Chẩn đoán**. Chọn
`🔎 Tìm phim` để gõ từ khóa; gõ trực tiếp ở danh sách phim để lọc nhanh trong
trang hiện tại.

## Các lệnh

| Lệnh | Việc nó làm |
| --- | --- |
| `hyde-shell rofi.movie` | Mở menu chính |
| `hyde-shell rofi.movie search [từ khóa]` | Tìm rồi phát |
| `hyde-shell rofi.movie browse [danh mục]` | Duyệt danh mục, thể loại, quốc gia, qua từng trang |
| `hyde-shell rofi.movie recent` | Phim mới cập nhật |
| `hyde-shell rofi.movie history` | Xem tiếp từ lịch sử trên máy |
| `hyde-shell rofi.movie play <slug>` | Phát theo slug |
| `hyde-shell rofi.movie link <slug> [tập]` | In link m3u8 thay vì phát |
| `hyde-shell rofi.movie open <slug>` | Mở trang phim trong trình duyệt |
| `hyde-shell rofi.movie settings` | Đổi trình phát, kiểu Rofi, nguồn ưu tiên, cache |
| `hyde-shell rofi.movie diagnose` | Kiểm tra công cụ và API |

`link` nhận số tập (bắt đầu từ 1) hoặc tên tập, ví dụ
`hyde-shell rofi.movie link naruto-shippuden 12` và
`hyde-shell rofi.movie link naruto-shippuden "Tập 12"` cho cùng một kết quả.

## Trình phát và nguồn phim

Thứ tự tìm trình phát: giá trị `player` trong cấu hình, rồi `mpv`, `vlc`,
`celluloid`, `haruna`, cuối cùng là `xdg-open`. Cần cài ít nhất một trình phát
(`sudo pacman -S mpv`); nếu không, link vẫn được mở bằng trình duyệt.

Khi phát, referer và user-agent của KKPhim được gửi kèm theo cách anisub vẫn
làm, vì máy chủ HLS từ chối request thiếu hai header này. Với `mpv`:

```txt
--force-media-title  --referrer  --user-agent  --http-header-fields  --cache
```

Nếu phim có nhiều nguồn (Vietsub, Lồng tiếng, Thuyết minh), bộ chọn đánh dấu
nguồn ưu tiên bằng `✔`. Đặt nguồn ưu tiên trong **⚙️ Cài đặt** hoặc bằng
`server_pref = "thuyet-minh"`. Khi nguồn đó không có tập tương ứng, tập đầu
tiên của nguồn khác được chọn.

## Cấu hình

Các khóa nằm trong `~/.config/hyde/config.toml` dưới bảng `[rofi.movie]` và
được `hyde-shell` xuất thành biến `ROFI_MOVIE_*`:

```toml
[rofi.movie]
player = ""              # để trống = tự tìm mpv, vlc, celluloid, haruna
style = "movie"          # theme Rofi của AniSub (bố cục clipboard + dòng mô tả)
scale = 10
font = "JetBrainsMono Nerd Font"
width = "46em"
server_pref = "auto"     # auto | vietsub | long-tieng | thuyet-minh
poster = true
limit = 24               # 1-64
detail_ttl = 600
site_url = "https://kkphim.com"
api_url = "https://phimapi.com"
cdn_url = "https://phimimg.com"
```

`hyde-shell rofi.movie settings` ghi trực tiếp vào bảng này; nếu chưa có
`config.toml`, giá trị được lưu trong state rc của HyDE. Hai biến chỉ dùng qua
môi trường: `ROFI_MOVIE_PROMPT=1` (dùng menu số trong terminal thay cho Rofi)
và `ROFI_MOVIE_VERIFY=1` (hỏi lại sau khi phát: phim có mở không, để lấy link
mới khi link đã hết hạn).

## Chữ và bố cục trên Rofi

Menu phim dùng theme `movie`
(`${XDG_DATA_HOME}/hyde/rofi/themes/movie.rasi`). Khác với các layout HyDE còn
lại, nó đặt `message` vào `children` của `mainbox`, nên dòng mô tả truyền bằng
`-mesg` (tóm tắt phim, số trang, gợi ý lọc) mới hiện ra — thiếu widget đó thì
Rofi bỏ hẳn dòng này. `rofi.movie` cũng tự chèn `message` vào đầu `children`
của theme đang dùng, nên khi đổi sang theme khác vẫn giữ được dòng mô tả (trừ
theme xếp `mainbox` ngang, vì chèn vào đó sẽ bóp hẹp danh sách).

Cùng trong theme này: `show-icons` bật để poster hiện cạnh tiêu đề, màu chữ
của `textbox` và `element-text` lấy từ `@main-fg` để nổi trên nền wallpaper mờ.
Nếu chữ vẫn khó đọc, mở **⚙️ Cài đặt** rồi chọn **🔠 Font chữ** (danh sách lấy
từ `fc-list`, chọn font có đủ dấu tiếng Việt) hoặc tăng **🔤 Cỡ chữ** (8-24).

## Poster và lịch sử

Poster được tải song song, lưu ở
`${XDG_CACHE_HOME}/hyde/rofi/movie/posters` và dùng làm icon của dòng
(`\0icon\x1f`). Ảnh `.webp` cần ImageMagick để chuyển sang PNG. Tắt poster
bằng `poster = false` nếu mạng chậm hoặc thiếu ImageMagick.

Lịch sử xem nằm ở `${XDG_STATE_HOME}/hyde/movie/history` (tối đa 40 phim, mỗi
phim một dòng) và chỉ lưu trên máy. Lần sau mở phim, tập đã xem được chọn sẵn.

## Chẩn đoán

```sh
hyde-shell rofi.movie diagnose
```

Lệnh này kiểm tra `rofi`, `curl`, `jq`, `awk`, `sed`, trình phát, ImageMagick,
`notify-send`, in ra các giá trị cấu hình đang dùng rồi gọi thử API tìm kiếm.
Nếu API trả về 200 mà không đọc được danh sách phim, rất có thể KKPhim đã đổi
định dạng — khi đó cần cập nhật `MOVIE_JQ_ROWS` trong script.

## Giới hạn hiện tại

Phần này chưa được thử trên một phiên Wayland thật trong môi trường phát triển:
`rofi` và `mpv` không có trong sandbox, nên luồng menu được kiểm tra bằng các
lệnh giả lập cùng fixture JSON của API. Nếu một menu không hiện, chạy
`diagnose` trước; nếu phim không mở, thử `hyde-shell rofi.movie link <slug>`
để xem link còn hiệu lực hay không. Khi API đổi cấu trúc, số liệu có thể trống
nhưng script không sửa hay xóa cấu hình của bạn.
