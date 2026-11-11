# Gõ tiếng Việt với IBus Unikey

AniDE cài `ibus` và `ibus-unikey`. `ibus-unikey` là gói thuộc repo chính thức
của Arch nên được cài bằng pacman, không phụ thuộc vào việc máy có yay/paru hay
không; hai helper đó vẫn được liệt kê để hỗ trợ bản AUR. Phiên Hyprland đặt các
biến GTK/Qt/XIM, khởi chạy IBus (không dùng `--replace` để tránh thay thế daemon
đang chạy) và **tự đăng ký engine tiếng Việt vào IBus** ngay lần đăng nhập đầu
tiên. Với UWSM, các biến môi trường cũng được thiết lập trước khi compositor
khởi động. Khởi động lại phiên sau khi cập nhật để mọi ứng dụng nhận môi trường
mới.

Sau khi đăng nhập chỉ cần nhấn `Ctrl+Space` để chuyển sang Unikey; chọn
Telex/VNI trong `ibus-setup-unikey`, hoặc mở **AniDE Settings → System →
Vietnamese input**. Kiểm tra nhanh bằng `ibus list-engine | grep -i unikey`
trong một phiên đang chạy.

## AniDE ghi những gì vào cấu hình IBus

`hyde-shell ibus-start` chạy lúc phiên khởi động và:

1. **Tìm engine tiếng Việt đã cài** bằng cách đọc
   `${XDG_DATA_DIRS}/ibus/component/*.xml` (mặc định là
   `/usr/share/ibus/component`). IBus-unikey khai báo engine động qua
   `<engines exec="/usr/lib/ibus/ibus-engine-unikey --xml"/>`, nên lệnh đó cũng
   được chạy (chỉ khi là đường dẫn tuyệt đối, có giới hạn thời gian) giống như
   cách IBus dựng registry. Ưu tiên `Unikey`, rồi `Bamboo`, rồi engine `vi` bất
   kỳ.
2. **Thêm** engine tìm được vào `org.freedesktop.ibus.general preload-engines`
   qua gsettings (hoặc dconf). Engine bạn đã cấu hình không bị xoá hay sắp xếp
   lại; `engines-order` chỉ được nối thêm khi bạn đã tự đặt danh sách đó.
3. **Đặt phím chuyển engine** thành `<Control>space` khi bạn chưa từng đổi nó.
   IBus bản hiện tại mặc định là `<Super>space` — trùng với tổ hợp phím hay
   được gán trong Hyprland (chính `hyprland.lua` của bạn gợi ý bind
   `SUPER + SPACE`), nên phím đó có thể không tới được IBus. "Chưa từng đổi"
   được xác định bằng dconf: key chưa được ghi nghĩa là chưa ai chọn; còn một
   danh sách đã ghi, kể cả danh sách rỗng, thì được giữ nguyên.
4. **Ghi dấu** đã đăng ký tại
   `${XDG_STATE_HOME:-~/.local/state}/hyde/ibus/vi-engine-seeded`, để những lần
   đăng nhập sau không đụng vào cấu hình nữa: engine bạn chủ động xoá sẽ không
   bị thêm lại. Nếu chưa cài engine nào, dấu này không được ghi, nên cài
   `ibus-unikey` sau vẫn được nhận ở lần đăng nhập kế tiếp.

Đăng ký lại hoặc kiểm tra bất cứ lúc nào:

```sh
hyde-shell ibus-start --seed --force # thêm lại engine tiếng Việt vào IBus
hyde-shell ibus-start --status       # biến môi trường, engine đã cài, phím chuyển, dấu đã ghi
hyde-shell ibus-start --seed         # chỉ đăng ký, không khởi động daemon
```

Cả hai nút trong **AniDE Settings → System** (`Vietnamese input` mở
`ibus-setup`, `Register Unikey again` chạy lệnh `--seed --force`) đều dùng đúng
những công cụ này; kết quả được báo bằng thông báo trên màn hình.

## Đổi engine, hoặc tắt hẳn tích hợp AniDE

Đặt các biến sau **trước khi đăng nhập** (ví dụ trong cấu hình môi trường UWSM
cá nhân `~/.config/uwsm/env`, trước snippet `10-anide-input.sh`), rồi đăng
xuất/đăng nhập. Với phiên không dùng UWSM, đặt biến trước khi chạy Hyprland.

| Biến | Giá trị | Tác dụng |
| --- | --- | --- |
| `ANIDE_INPUT_METHOD` | `none` (hoặc khác `auto`/`ibus`) | AniDE không đặt biến toolkit, không đăng ký engine, không khởi động IBus |
| `ANIDE_IBUS_ENGINE` | `none` | Vẫn khởi động IBus nhưng không đăng ký engine tiếng Việt |
| `ANIDE_IBUS_ENGINE` | `Bamboo`, ... | Đăng ký engine khác thay cho `Unikey` |

Nếu đã dùng Fcitx hoặc framework khác, các biến `GTK_IM_MODULE`, `QT_IM_MODULE`
và `XMODIFIERS` hiện có được tôn trọng như một nhóm; AniDE không đăng ký engine
và không khởi động daemon khi phát hiện Fcitx đang chạy hoặc một trong ba biến
đó trỏ đi nơi khác. Nếu Fcitx khởi chạy mà không khai báo các biến toolkit, hãy
tắt mặc định IBus để tránh trỏ ứng dụng tới IBus trong khi daemon không chạy.
Không cần đổi cấu hình `.conf` của Hyprland.

## Khắc phục sự cố

- `Ctrl+Space` không đổi bàn phím: chạy `hyde-shell ibus-start --status`. Nếu
  `preload-engines` thiếu engine tiếng Việt, chạy
  `hyde-shell ibus-start --seed --force`. Nếu `switch key` vẫn là
  `<Super>space` thì tổ hợp đó có thể đã bị Hyprland giữ: đổi phím trong
  `ibus-setup` (General → Keyboard Shortcuts), hoặc bỏ bind đó trong
  `~/.config/hypr/hyprland.lua`.
- `vi engines installed : <none>`: gói engine chưa cài
  (`sudo pacman -S ibus-unikey`), hoặc IBus tìm component ở thư mục khác; xem
  thêm `ANIDE_IBUS_COMPONENT_DIRS` trong chính script.
- Ứng dụng vẫn không gõ được tiếng Việt: kiểm tra biến môi trường của chính ứng
  dụng đó (`GTK_IM_MODULE`, `QT_IM_MODULE`, `XMODIFIERS`) — ứng dụng mở trước
  khi phiên đặt biến sẽ không nhận chúng, cần mở lại.
- Muốn cấu hình lại từ đầu: xoá
  `~/.local/state/hyde/ibus/vi-engine-seeded`, chỉnh engine trong `ibus-setup`,
  rồi đăng nhập lại.

IBus hoạt động qua IM module GTK/Qt và XIM cho XWayland; hành vi có thể khác
nhau theo ứng dụng, đặc biệt ứng dụng Electron/Wayland native. Kiểm tra trong
GTK, Qt và XWayland trên hệ thống của bạn. IBus-Unikey upstream hiện không còn
được hỗ trợ tích cực; xem [upstream](https://github.com/vn-input/ibus-unikey)
để biết các lựa chọn khác. Logic đăng ký engine được kiểm thử bằng binary giả
lập trong `checks/test_ibus_integration.py`, chưa kiểm thử trên một phiên
Hyprland thật trong môi trường phát triển.
