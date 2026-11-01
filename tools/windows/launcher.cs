// V-OS.exe - starts CPCEMU as a CPC 6128 with a 512K RAM expansion, an
// AMX mouse and an M4 board, V-OS in drive A: and its programs in drive B:
// (cpcemu\vos.cfg); V-OS starts by itself (DISC.BAS on drive A:).
// Built by tools/mkwindows.sh with the C# compiler of Windows' .NET.
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

class Launcher
{
    [STAThread]
    static void Main()
    {
        string home = AppDomain.CurrentDomain.BaseDirectory;
        string emu = Path.Combine(home, "cpcemu");
        string exe = Path.Combine(emu, "cpcemu_portable.exe");
        foreach (string f in new string[] { exe, Path.Combine(emu, "vos.cfg"),
                 Path.Combine(emu, "DISC", "VOS.DSK"), Path.Combine(emu, "DISC", "APPS.DSK") })
        {
            if (!File.Exists(f))
            {
                MessageBox.Show("Missing: " + f, "V-OS", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
        }
        ProcessStartInfo p = new ProcessStartInfo();
        p.FileName = exe;
        p.WorkingDirectory = emu;
        p.UseShellExecute = false;
        p.Arguments = "-c vos.cfg -t 2";
        try
        {
            Process.Start(p);
        }
        catch (Exception e)
        {
            MessageBox.Show(e.Message, "V-OS", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
