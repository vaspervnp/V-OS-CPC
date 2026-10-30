// V-OS.exe - starts Caprice32 as a CPC 6128 with a 512K RAM expansion,
// V-OS in drive A: and VROUVES in drive B:, and runs V-OS.
// Built by tools/mkwindows.sh with the C# compiler of Windows' .NET.
// Its folder holds caprice32\ (cap32.exe, cap32.cfg, rom\ ...) and
// disks\ (vos.dsk, vrouves.dsk).
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

class Launcher
{
    static string Quote(string s)
    {
        return "\"" + s.Replace("\"", "\\\"") + "\"";
    }

    [STAThread]
    static void Main()
    {
        string home = AppDomain.CurrentDomain.BaseDirectory;
        string cap = Path.Combine(home, "caprice32");
        string exe = Path.Combine(cap, "cap32.exe");
        string a = Path.Combine(home, "disks", "vos.dsk");
        string b = Path.Combine(home, "disks", "vrouves.dsk");
        foreach (string f in new string[] { exe, a, b })
        {
            if (!File.Exists(f))
            {
                MessageBox.Show("Missing: " + f, "V-OS", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
        }
        ProcessStartInfo p = new ProcessStartInfo();
        p.FileName = exe;
        p.WorkingDirectory = cap;
        p.UseShellExecute = false;
        p.Arguments = "--cfg_file=" + Quote(Path.Combine(cap, "cap32.cfg"))
            + " -O system.model=2 -O system.ram_size=576"
            + " -a " + Quote("run\"vos\n")
            + " " + Quote(a) + " " + Quote(b);
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
