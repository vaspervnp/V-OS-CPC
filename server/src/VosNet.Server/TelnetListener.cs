using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using VosNet.Core;

namespace VosNet.Server;

/// <summary>The ports the listeners got (a port 0 in the settings is a
/// free one: the tests).</summary>
public sealed class TelnetEndpoints
{
    readonly ConcurrentDictionary<int, int> _ports = new();
    readonly TaskCompletionSource _ready = new(TaskCreationOptions.RunContinuationsAsynchronously);
    int _expected;

    public void Expect(int n) => _expected = n;
    public IReadOnlyCollection<int> Ports => _ports.Values.ToList();

    internal void Bound(int configured, int actual)
    {
        _ports[configured] = actual;
        if (_ports.Count >= _expected) _ready.TrySetResult();
    }

    internal void Failed() { if (--_expected <= _ports.Count) _ready.TrySetResult(); }

    public Task Ready => _ready.Task;
}

/// <summary>A telnet port (23, 2323): each connection to the
/// <see cref="ConnectionHandler"/>, in a task of its own.</summary>
public sealed class TelnetListener(int port, ConnectionHandler handler, TelnetEndpoints endpoints, ILogger<TelnetListener> log)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        // IPv4 and IPv6 apart (not one dual socket): WSL passes to Windows
        // only what listens on IPv4, and IPv6 may be off
        var listeners = new List<TcpListener>();
        try
        {
            var v4 = new TcpListener(IPAddress.Any, port);
            v4.Start();
            listeners.Add(v4);
        }
        catch (SocketException e)
        {
            log.LogError("Telnet port {Port}: {Error}", port, e.Message);
            endpoints.Failed();
            return;
        }
        var actual = ((IPEndPoint)listeners[0].LocalEndpoint).Port;
        if (Socket.OSSupportsIPv6)
            try
            {
                var v6 = new TcpListener(IPAddress.IPv6Any, actual);
                v6.Server.DualMode = false;
                v6.Start();
                listeners.Add(v6);
            }
            catch (SocketException) { }
        endpoints.Bound(port, actual);
        log.LogInformation("Telnet on port {Port}", actual);
        var open = new ConcurrentDictionary<Task, bool>();
        try
        {
            await Task.WhenAll(listeners.Select(l => AcceptAsync(l, actual, open, ct)));
        }
        finally
        {
            foreach (var l in listeners) l.Stop();
            await Task.WhenAny(Task.WhenAll(open.Keys), Task.Delay(TimeSpan.FromSeconds(5), CancellationToken.None));
        }
    }

    async Task AcceptAsync(TcpListener listener, int actual, ConcurrentDictionary<Task, bool> open, CancellationToken ct)
    {
        try
        {
            while (!ct.IsCancellationRequested)
            {
                var client = await listener.AcceptTcpClientAsync(ct);
                client.NoDelay = true;
                var remote = (IPEndPoint)client.Client.RemoteEndPoint!;
                var t = Task.Run(async () =>
                {
                    using (client) await handler.HandleAsync(client.GetStream(), remote.Address, actual, ct);
                }, CancellationToken.None);
                open[t] = true;
                _ = t.ContinueWith(x => open.TryRemove(x, out _), TaskScheduler.Default);
            }
        }
        catch (OperationCanceledException) { }
    }
}
