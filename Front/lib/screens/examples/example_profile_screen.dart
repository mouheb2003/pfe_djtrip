import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../utils/auth_error_handler.dart';

/// EXEMPLE D'UTILISATION DU SYSTÈME D'AUTO-REFRESH
///
/// Ce fichier montre comment utiliser le nouveau système de gestion automatique
/// des tokens expirés dans vos écrans Flutter.

class ExampleProfileScreen extends StatefulWidget {
  const ExampleProfileScreen({super.key});

  @override
  State<ExampleProfileScreen> createState() => _ExampleProfileScreenState();
}

class _ExampleProfileScreenState extends State<ExampleProfileScreen> {
  bool _isLoading = false;
  String _fullname = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// Exemple 1 : Charger les données utilisateur
  /// Le token se rafraîchit automatiquement si expiré !
  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    // Appel API avec auto-refresh du token
    final result = await UserService.getUserInfo();

    if (mounted) {
      // Gérer les erreurs d'authentification
      AuthErrorHandler.handleAuthError(context, result);

      if (result['success']) {
        final user = result['user'];
        setState(() {
          _fullname = user.fullname;
          _email = user.email;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Exemple 2 : Mettre à jour le profil
  /// Le token se rafraîchit automatiquement si expiré !
  Future<void> _updateProfile(String newName) async {
    setState(() {
      _isLoading = true;
    });

    // Appel API avec auto-refresh du token
    final result = await UserService.updateProfile({'fullname': newName});

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Gérer les erreurs d'authentification
      AuthErrorHandler.handleAuthError(context, result);

      if (result['success']) {
        // Succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil mis à jour avec succès !'),
            backgroundColor: Colors.green,
          ),
        );

        // Recharger les données
        _loadUserInfo();
      }
    }
  }

  /// Exemple 3 : Dialogue de modification
  void _showEditDialog() {
    final controller = TextEditingController(text: _fullname);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier le nom'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nom complet',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateProfile(controller.text);
            },
            child: Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrapper qui vérifie l'authentification
    return AuthRequiredWidget(
      onSessionExpired: () {
        print('⚠️ Session expirée, utilisateur redirigé vers login');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Mon Profil (Exemple)'),
          backgroundColor: Color(0xFFFF6B1A),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info box explicative
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              SizedBox(width: 8),
                              Text(
                                'Système d\'auto-refresh actif',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ce profil utilise le nouveau système de gestion des tokens. '
                            'Si votre token expire pendant l\'utilisation, il sera '
                            'automatiquement rafraîchi sans vous déconnecter !',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),

                    // Avatar placeholder
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Color(0xFFFF6B1A).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFFFF6B1A),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),

                    // Informations utilisateur
                    _buildInfoCard(
                      icon: Icons.person_outline,
                      label: 'Nom complet',
                      value: _fullname,
                      onEdit: _showEditDialog,
                    ),
                    SizedBox(height: 16),
                    _buildInfoCard(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: _email,
                    ),
                    SizedBox(height: 32),

                    // Boutons de test
                    Text(
                      'Tests du système :',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildTestButton(
                      'Recharger les données',
                      Icons.refresh,
                      _loadUserInfo,
                      Colors.blue,
                    ),
                    SizedBox(height: 12),
                    _buildTestButton(
                      'Modifier le profil',
                      Icons.edit,
                      _showEditDialog,
                      Color(0xFFFF6B1A),
                    ),
                    SizedBox(height: 24),

                    // Note
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Token valide pendant 2h, puis rafraîchi automatiquement',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFFFF6B1A)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit, size: 20),
              onPressed: onEdit,
              color: Color(0xFFFF6B1A),
            ),
        ],
      ),
    );
  }

  Widget _buildTestButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
