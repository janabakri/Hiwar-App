import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  String _gender = 'ذكر';
  String _goal = 'السفر';
  String _level = 'متوسط (B1)';
  String _interest = 'التكنولوجيا';
  bool _isEditing = false;

  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  final Dio _dio = Dio();
  String _userId = 'sarah_123';

  // قائمة الخيارات
  final List<String> _genderOptions = ['ذكر', 'أنثى'];
  final List<String> _goalOptions = [
    'السفر',
    'العمل',
    'الدراسة',
    'الهجرة',
    'التواصل مع الأصدقاء',
    'تطوير الذات',
  ];
  final List<String> _levelOptions = [
    'مبتدئ (A1)',
    'مبتدئ متقدم (A2)',
    'متوسط (B1)',
    'متوسط متقدم (B2)',
    'متقدم (C1)',
    'متقدم جداً (C2)',
  ];
  final List<String> _interestOptions = [
    'التكنولوجيا',
    'الأعمال',
    'الطب',
    'الهندسة',
    'الفنون',
    'الرياضة',
    'السفر',
    'الطعام',
    'الأفلام',
    'الموسيقى',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId') ?? 'sarah_123';

      final response = await _dio.get(
        'http://localhost:8000/api/v1/user/profile/$_userId',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _userData = data;
          _nameController.text = data['name'] ?? '';
          _ageController.text = data['age']?.toString() ?? '';
          _cityController.text = data['city'] ?? '';
          _gender = data['gender'] ?? 'ذكر';
          _goal = data['goal'] ?? 'السفر';
          _level = data['level'] ?? 'متوسط (B1)';
          _interest = data['interest'] ?? 'التكنولوجيا';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final response = await _dio.post(
          'http://localhost:8000/api/v1/user/profile',
          data: {
            'user_id': _userId,
            'name': _nameController.text,
            'age': int.tryParse(_ageController.text) ?? 0,
            'gender': _gender,
            'city': _cityController.text,
            'goal': _goal,
            'level': _level,
            'interest': _interest,
          },
        );

        if (response.statusCode == 200) {
          setState(() {
            _isEditing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم حفظ الملف الشخصي بنجاح!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: Text(
          'معلوماتي الشخصية',
          style: GoogleFonts.tajawal(),
        ),
        backgroundColor: const Color(0xFF1C1C2E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar Section
                    _buildAvatar(),

                    const SizedBox(height: 24),

                    // Personal Info
                    _buildSection('المعلومات الشخصية', [
                      _buildTextField(
                        label: 'الاسم',
                        controller: _nameController,
                        icon: Icons.person,
                        enabled: _isEditing,
                      ),
                      _buildTextField(
                        label: 'العمر',
                        controller: _ageController,
                        icon: Icons.cake,
                        keyboardType: TextInputType.number,
                        enabled: _isEditing,
                      ),
                      _buildDropdown(
                        label: 'الجنس',
                        value: _gender,
                        options: _genderOptions,
                        onChanged: _isEditing
                            ? (value) => setState(() => _gender = value!)
                            : null,
                      ),
                      _buildTextField(
                        label: 'المدينة',
                        controller: _cityController,
                        icon: Icons.location_city,
                        enabled: _isEditing,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Learning Info
                    _buildSection('هدفك من التعلم', [
                      _buildDropdown(
                        label: 'لماذا تتعلم الإنجليزية؟',
                        value: _goal,
                        options: _goalOptions,
                        onChanged: _isEditing
                            ? (value) => setState(() => _goal = value!)
                            : null,
                      ),
                      _buildDropdown(
                        label: 'مستواك الحالي',
                        value: _level,
                        options: _levelOptions,
                        onChanged: _isEditing
                            ? (value) => setState(() => _level = value!)
                            : null,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Interests
                    _buildSection('اهتماماتك', [
                      _buildDropdown(
                        label: 'مجال اهتمامك الرئيسي',
                        value: _interest,
                        options: _interestOptions,
                        onChanged: _isEditing
                            ? (value) => setState(() => _interest = value!)
                            : null,
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Edit Mode Info
                    if (_isEditing)
                      Text(
                        '✏️ اضغط على أيقونة 💾 في الأعلى لحفظ التغييرات',
                        style: GoogleFonts.tajawal(
                          color: const Color(0xFFF2A93B),
                          fontSize: 12,
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF1A8F80)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _nameController.text.isNotEmpty
              ? _nameController.text[0].toUpperCase()
              : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade800),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2DD4BF)),
          ),
          filled: true,
          fillColor: enabled ? const Color(0xFF0D0D1A) : const Color(0xFF1A1A2E),
        ),
        validator: (value) {
          if (value?.isEmpty ?? true) return 'هذا الحقل مطلوب';
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required void Function(String?)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        dropdownColor: const Color(0xFF1C1C2E),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade400),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade800),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2DD4BF)),
          ),
          filled: true,
          fillColor: onChanged != null ? const Color(0xFF0D0D1A) : const Color(0xFF1A1A2E),
        ),
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
        validator: (value) {
          if (value == null || value.isEmpty) return 'اختر خياراً';
          return null;
        },
      ),
    );
  }
}
