using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
namespace ACROptimal.Ocr {
 public static class TitleCapture {
  [StructLayout(LayoutKind.Sequential)] struct RECT {public int Left,Top,Right,Bottom;}
  [StructLayout(LayoutKind.Sequential)] struct POINT {public int X,Y;}
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd,out RECT rect);
  [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd,ref POINT point);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint id);
  public static string Capture(string path,string[] processNames,double x,double y,double w,double h) {
   IntPtr hwnd=GetForegroundWindow();uint id;GetWindowThreadProcessId(hwnd,out id);
   using(var p=Process.GetProcessById((int)id)) {
    bool matches=false;foreach(string name in processNames) if(String.Equals(p.ProcessName,name.Replace(".exe",""),StringComparison.OrdinalIgnoreCase)) matches=true;
    if(!matches) throw new InvalidOperationException("Mettre le jeu au premier plan avant la capture.");
    RECT r;if(!GetClientRect(hwnd,out r)) throw new InvalidOperationException("Fenetre du jeu inaccessible.");
    if(Double.IsNaN(x) || Double.IsNaN(y) || Double.IsNaN(w) || Double.IsNaN(h) || Double.IsInfinity(x) || Double.IsInfinity(y) || Double.IsInfinity(w) || Double.IsInfinity(h) || x<0 || y<0 || w<=0 || h<=0 || x+w>100 || y+h>100 || h>15) throw new InvalidOperationException("Zone de titre invalide (pourcentages, hauteur maximale 15 %).");
    int cw=r.Right-r.Left,ch=r.Bottom-r.Top;
    if(cw<=0 || ch<=0) throw new InvalidOperationException("Fenetre minimisee ou dimensions invalides.");
    POINT point=new POINT {X=(int)Math.Round(cw*x/100),Y=(int)Math.Round(ch*y/100)};
    if(!ClientToScreen(hwnd,ref point)) throw new InvalidOperationException("Coordonnees du jeu indisponibles.");
    int width=Math.Max(1,(int)Math.Round(cw*w/100)),height=Math.Max(1,(int)Math.Round(ch*h/100));
    using(var bmp=new Bitmap(width,height,PixelFormat.Format32bppArgb)) using(var g=Graphics.FromImage(bmp)) {
     g.CopyFromScreen(point.X,point.Y,0,0,new Size(width,height),CopyPixelOperation.SourceCopy);bmp.Save(path,ImageFormat.Png);
    }
    return p.ProcessName;
   }
  }
 }
}
