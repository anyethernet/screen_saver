using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

internal static class MakeAssets
{
    private static readonly string IconPath = @"C:\Users\anyet\.cursor\projects\c-Projects-screen-saver\assets\icon-512-source.jpg";
    private static readonly string RoomPath = @"C:\Users\anyet\.cursor\projects\c-Projects-screen-saver\assets\room-preview.jpg";
    private static readonly string OutDir = @"C:\Projects\screen_saver\play-store";

    private static Color Navy;
    private static readonly Color Cream = Color.FromArgb(246, 241, 231);
    private static readonly Color Amber = Color.FromArgb(232, 168, 62);
    private static readonly Color Teal = Color.FromArgb(46, 143, 148);
    private static readonly Color Muted = Color.FromArgb(186, 198, 214);
    private static readonly Color Card = Color.FromArgb(16, 42, 74);

    private static FontFamily Family;

    public static int Main()
    {
        Directory.CreateDirectory(OutDir);
        using (Image icon = Image.FromFile(IconPath))
        using (Image room = Image.FromFile(RoomPath))
        using (var probe = new Bitmap(icon))
        {
            Navy = probe.GetPixel(8, 8);
            Family = new FontFamily("Malgun Gothic");
            SaveIcon(icon);
            SaveFeature(icon, room);
            SavePhone(icon, room, "phone-01-camera.jpg", "집에 둔 폰이\n카메라가 됩니다", "남아 있는 안드로이드 폰의 카메라로\n집안을 비춥니다.", Screen.Camera);
            SavePhone(icon, room, "phone-02-viewer.jpg", "밖에서는\n내 폰으로 봅니다", "집 카메라 IP만 넣으면\n실시간 영상을 봅니다.", Screen.Viewer);
            SavePhone(icon, room, "phone-03-control.jpg", "영상을 보면서\n집을 조작합니다", "조명 같은 명령은\n집 안 카메라 폰이 실행합니다.", Screen.Control);
            SavePhone(icon, room, "phone-04-saver.jpg", "화면 보호기로\n아이들을 봅니다", "폰이 쉬는 화면에도\n원격 영상을 띄울 수 있습니다.", Screen.Saver);
            SavePhone(icon, room, "phone-05-roles.jpg", "앱은 하나\n역할만 고릅니다", "집에서는 카메라,\n밖에서는 뷰어로 씁니다.", Screen.Roles);
        }
        Console.WriteLine("wrote " + OutDir);
        return 0;
    }

    private enum Screen { Camera, Viewer, Control, Saver, Roles }

    private static void SaveIcon(Image icon)
    {
        using (var bmp = new Bitmap(512, 512, PixelFormat.Format32bppArgb))
        using (var g = Graphics.FromImage(bmp))
        {
            Quality(g);
            g.DrawImage(icon, new Rectangle(0, 0, 512, 512));
            bmp.Save(Path.Combine(OutDir, "icon-512.png"), ImageFormat.Png);
        }
    }

    private static void SaveFeature(Image icon, Image room)
    {
        const int w = 1024;
        const int h = 500;
        using (var bmp = new Bitmap(w, h, PixelFormat.Format24bppRgb))
        using (var g = Graphics.FromImage(bmp))
        {
            Quality(g);
            g.Clear(Navy);
            DrawCover(g, room, new Rectangle(560, 0, 464, h));
            using (var fade = new LinearGradientBrush(new Rectangle(520, 0, 180, h), Navy, Color.FromArgb(0, Navy), 0f))
            {
                g.FillRectangle(fade, 520, 0, 180, h);
            }
            using (var navy = new SolidBrush(Navy))
            {
                g.FillRectangle(navy, 0, 0, 560, h);
            }
            g.DrawImage(icon, new Rectangle(36, 125, 210, 210));
            using (var title = new Font(Family, 40f, FontStyle.Bold, GraphicsUnit.Pixel))
            using (var sub = new Font(Family, 22f, FontStyle.Regular, GraphicsUnit.Pixel))
            using (var brush = new SolidBrush(Cream))
            using (var muted = new SolidBrush(Muted))
            {
                g.DrawString("원격 카메라", title, brush, 268, 175);
                g.DrawString("집에 둔 폰으로 보고\n밖에서는 내 폰으로", sub, muted, 270, 240);
            }
            using (var accent = new SolidBrush(Amber))
            {
                g.FillRectangle(accent, 270, 330, 72, 6);
            }
            SaveJpeg(bmp, Path.Combine(OutDir, "feature-graphic-1024x500.jpg"));
        }
    }

    private static void SavePhone(Image icon, Image room, string name, string title, string subtitle, Screen screen)
    {
        const int w = 1080;
        const int h = 1920;
        using (var bmp = new Bitmap(w, h, PixelFormat.Format24bppRgb))
        using (var g = Graphics.FromImage(bmp))
        {
            Quality(g);
            using (var bg = new LinearGradientBrush(new Rectangle(0, 0, w, h), Navy, Color.FromArgb(7, 24, 48), 90f))
            {
                g.FillRectangle(bg, 0, 0, w, h);
            }
            g.DrawImage(icon, new Rectangle(72, 78, 84, 84));
            using (var kicker = new Font(Family, 28f, FontStyle.Bold, GraphicsUnit.Pixel))
            using (var brush = new SolidBrush(Cream))
            {
                g.DrawString("원격 카메라", kicker, brush, 176, 100);
            }
            using (var accent = new SolidBrush(Amber))
            {
                g.FillRectangle(accent, 72, 196, 72, 8);
            }
            using (var titleFont = new Font(Family, 72f, FontStyle.Bold, GraphicsUnit.Pixel))
            using (var subFont = new Font(Family, 34f, FontStyle.Regular, GraphicsUnit.Pixel))
            using (var brush = new SolidBrush(Cream))
            using (var muted = new SolidBrush(Muted))
            {
                g.DrawString(title, titleFont, brush, new RectangleF(72, 230, 936, 280));
                g.DrawString(subtitle, subFont, muted, new RectangleF(72, 530, 900, 160));
            }
            var card = new Rectangle(64, 740, 952, 1060);
            FillRound(g, card, 40, Card);
            DrawScreen(g, room, card, screen);
            SaveJpeg(bmp, Path.Combine(OutDir, name));
        }
    }

    private static void DrawScreen(Graphics g, Image room, Rectangle card, Screen screen)
    {
        int pad = 28;
        var inner = new Rectangle(card.X + pad, card.Y + pad, card.Width - pad * 2, card.Height - pad * 2);
        if (screen == Screen.Camera || screen == Screen.Viewer || screen == Screen.Saver)
        {
            int videoH = screen == Screen.Saver ? inner.Height - 110 : inner.Height - 250;
            var video = new Rectangle(inner.X, inner.Y, inner.Width, videoH);
            DrawImageRounded(g, room, video, 28);
            Pill(g, screen == Screen.Camera ? "송출 중" : screen == Screen.Viewer ? "Tailscale 연결됨" : "화면 보호", new Rectangle(video.X + 28, video.Y + 28, screen == Screen.Viewer ? 280 : 180, 64), Teal, Cream);
            if (screen != Screen.Saver)
            {
                int y = video.Bottom + 28;
                Label(g, "거실", 36, FontStyle.Bold, Cream, inner.X, y);
                Label(g, screen == Screen.Camera ? "이 폰의 카메라가 영상을 보내고 있습니다" : "밖에서 집 카메라 영상을 보고 있습니다", 26, FontStyle.Regular, Muted, inner.X, y + 58);
                Pill(g, screen == Screen.Camera ? "이 폰은 카메라" : "원격 카메라를 보기", new Rectangle(inner.X, y + 130, screen == Screen.Camera ? 280 : 340, 72), Amber, Color.FromArgb(28, 32, 28));
            }
            else
            {
                Label(g, "거실  ·  아이들 방", 32, FontStyle.Bold, Cream, inner.X, video.Bottom + 28);
            }
            return;
        }
        if (screen == Screen.Control)
        {
            var video = new Rectangle(inner.X, inner.Y, inner.Width, 520);
            DrawImageRounded(g, room, video, 28);
            Pill(g, "보는 중", new Rectangle(video.X + 28, video.Y + 28, 160, 64), Teal, Cream);
            Label(g, "거실 조명", 36, FontStyle.Bold, Cream, inner.X, video.Bottom + 36);
            Label(g, "누른 명령은 집 카메라 폰이 실행합니다", 26, FontStyle.Regular, Muted, inner.X, video.Bottom + 92);
            Pill(g, "조명 켜기", new Rectangle(inner.X, video.Bottom + 170, 400, 92), Amber, Color.FromArgb(28, 32, 28));
            Pill(g, "조명 끄기", new Rectangle(inner.X + 424, video.Bottom + 170, 400, 92), Color.FromArgb(32, 58, 92), Cream);
            return;
        }
        Label(g, "이 폰의 역할", 32, FontStyle.Bold, Cream, inner.X, inner.Y + 8);
        Choice(g, new Rectangle(inner.X, inner.Y + 80, inner.Width, 220), "이 폰은 카메라", "집 안에서 영상을 보냅니다", true);
        Choice(g, new Rectangle(inner.X, inner.Y + 330, inner.Width, 220), "원격 카메라를 보기", "밖에서 영상을 보고 조작합니다", false);
        Label(g, "연결 방법", 28, FontStyle.Bold, Cream, inner.X, inner.Y + 590);
        Pill(g, "Tailscale", new Rectangle(inner.X, inner.Y + 660, 250, 76), Amber, Color.FromArgb(28, 32, 28));
        Pill(g, "포트포워딩", new Rectangle(inner.X + 274, inner.Y + 660, 280, 76), Color.FromArgb(32, 58, 92), Cream);
    }

    private static void Choice(Graphics g, Rectangle rect, string title, string sub, bool selected)
    {
        FillRound(g, rect, 28, selected ? Color.FromArgb(34, 68, 108) : Color.FromArgb(22, 48, 82));
        if (selected)
        {
            using (var pen = new Pen(Amber, 4))
            {
                DrawRound(g, rect, 28, pen);
            }
        }
        Label(g, title, 36, FontStyle.Bold, Cream, rect.X + 36, rect.Y + 48);
        Label(g, sub, 26, FontStyle.Regular, Muted, rect.X + 36, rect.Y + 112);
    }

    private static void Label(Graphics g, string text, float size, FontStyle style, Color color, int x, int y)
    {
        using (var font = new Font(Family, size, style, GraphicsUnit.Pixel))
        using (var brush = new SolidBrush(color))
        {
            g.DrawString(text, font, brush, x, y);
        }
    }

    private static void Pill(Graphics g, string text, Rectangle rect, Color fill, Color textColor)
    {
        FillRound(g, rect, rect.Height / 2, fill);
        using (var font = new Font(Family, 28f, FontStyle.Bold, GraphicsUnit.Pixel))
        using (var brush = new SolidBrush(textColor))
        using (var format = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
        {
            g.DrawString(text, font, brush, rect, format);
        }
    }

    private static void FillRound(Graphics g, Rectangle rect, int radius, Color color)
    {
        using (var path = Round(rect, radius))
        using (var brush = new SolidBrush(color))
        {
            g.FillPath(brush, path);
        }
    }

    private static void DrawRound(Graphics g, Rectangle rect, int radius, Pen pen)
    {
        using (var path = Round(rect, radius))
        {
            g.DrawPath(pen, path);
        }
    }

    private static GraphicsPath Round(Rectangle rect, int radius)
    {
        int d = radius * 2;
        var path = new GraphicsPath();
        path.AddArc(rect.X, rect.Y, d, d, 180, 90);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    private static void DrawImageRounded(Graphics g, Image img, Rectangle dest, int radius)
    {
        using (var path = Round(dest, radius))
        {
            g.SetClip(path);
            DrawCover(g, img, dest);
            g.ResetClip();
        }
    }

    private static void DrawCover(Graphics g, Image img, Rectangle dest)
    {
        float scale = Math.Max((float)dest.Width / img.Width, (float)dest.Height / img.Height);
        int w = (int)Math.Ceiling(img.Width * scale);
        int h = (int)Math.Ceiling(img.Height * scale);
        var draw = new Rectangle(dest.X + (dest.Width - w) / 2, dest.Y + (dest.Height - h) / 2, w, h);
        g.DrawImage(img, draw);
    }

    private static void Quality(Graphics g)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
    }

    private static void SaveJpeg(Image image, string path)
    {
        var codec = Array.Find(ImageCodecInfo.GetImageEncoders(), item => item.MimeType == "image/jpeg");
        using (var encoder = new EncoderParameters(1))
        {
            encoder.Param[0] = new EncoderParameter(Encoder.Quality, 92L);
            image.Save(path, codec, encoder);
        }
    }
}
