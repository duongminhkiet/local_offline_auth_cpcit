import 'package:flutter/material.dart';
import 'package:local_offline_auth_cpcit/local_offline_auth_cpcit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Auth Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0c6fff)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isProcessingLoginApiOrOffline = false;
  bool _isNetworkAvailable = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Điều hướng sang trang chủ
  void _navigateToHome(String username) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => HomePage(username: username)),
    );
  }

  // Xử lý nút Đăng nhập chính
  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fill in all fields.')));
      return;
    }

    if (_isNetworkAvailable) {
      await _loginOnlineAPI(username, password);
    } else {
      await _loginOffline(username, password);
    }
  }

  // Giả lập đăng nhập Online qua API
  Future<void> _loginOnlineAPI(String username, String password) async {
    setState(() => _isProcessingLoginApiOrOffline = true);

    // 1. Giả lập gọi API login thực tế mất khoảng 2 giây
    await Future.delayed(const Duration(milliseconds: 1000));

    // Giả định API trả về thành công...
    bool isLoginAPISuccess = true;

    if (isLoginAPISuccess && mounted) {
      bool autoResigterPin = await OfflineAuthService.registerGeneratedPinAuto(
        username: username,
      );

      setState(() => _isProcessingLoginApiOrOffline = false);

      if (autoResigterPin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Login online success and auto register pin success!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login online success but not auto register pin.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      // 3. Chuyển sang trang chủ
      _navigateToHome(username);
    }
  }

  Future<void> _loginOffline(String username, String password) async {
    setState(() => _isProcessingLoginApiOrOffline = true);

    // Giả lập gọi API login mất 1.5 giây
    await Future.delayed(const Duration(milliseconds: 3000));
    await OfflineAuthService.authenticateWithPin(
      context: context,
      username: _usernameController.text,
      inputPin: _passwordController.text,
      onSuccess: () => _navigateToHome(_usernameController.text),
      onStorageInvalidated: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You need to re-login to set up new offline PIN.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          _passwordController.clear();
        }
      },
    );

    if (mounted) {
      setState(() => _isProcessingLoginApiOrOffline = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.security, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                "DEMO APP",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // Checkbox giả lập mạng
              Container(
                decoration: BoxDecoration(
                  color: _isNetworkAvailable
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  title: const Text("Internet connection (DEMO)"),
                  subtitle: Text(_isNetworkAvailable ? "Online" : "Offline"),
                  value: _isNetworkAvailable,
                  onChanged: (bool? value) {
                    setState(() {
                      _isNetworkAvailable = value ?? false;
                    });
                  },
                  secondary: Icon(
                    _isNetworkAvailable ? Icons.wifi : Icons.wifi_off,
                    color: _isNetworkAvailable ? Colors.green : Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // onChanged: (value) => _checkOfflineStatus(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isProcessingLoginApiOrOffline
                      ? null
                      : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessingLoginApiOrOffline
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              OfflineAuthService.buildBiometricLoginButton(
                context: context,
                username: _usernameController.text.trim(),
                isLoading: _isProcessingLoginApiOrOffline,
                onSuccess: () => _navigateToHome(
                  _usernameController.text,
                ), // Chỉ quan tâm khi thành công
              ),

              const SizedBox(height: 40),
              TextButton(
                onPressed: () async {
                  final username = _usernameController.text.trim();
                  if (username.isNotEmpty) {
                    await OfflineAuthService.clearOfflineAuthData(
                      username: username,
                    );
                    _usernameController.clear();
                    _passwordController.clear();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed offline data.')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter username to remove offline data.'),
                      ),
                    );
                  }
                },
                child: const Text("Delete Offline Data (Reset Demo)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String username;

  const HomePage({super.key, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? localNumberPass;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    String? localNumberPassX = await OfflineAuthService.getPinFromSecureStorage(
      username: widget.username,
    );
    if (localNumberPassX != null) {
      if (mounted) {
        setState(() {
          localNumberPass = localNumberPassX;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home, size: 100, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'Hello, ${widget.username}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (localNumberPass != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Offline PIN:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localNumberPass!,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Login success!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Login Screen'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
