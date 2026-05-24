const fs = require('fs');
const path = 'Front/lib/screens/tourist/tabs/tourist_profile_tab.dart';
let content = fs.readFileSync(path, 'utf8');

const regex = /              \/\/ Unified stats bar: Posts \| Reservations \| Relations\r?\n                      Expanded\(\r?\n                        child: _StatItem\(\r?\n                          value: '\$_bookingsCount',\r?\n                          label: 'Reservations',\r?\n                        \),\r?\n                      \),\r?\n                      Container\(\r?\n                        width: 1,\r?\n                        height: 34,\r?\n                        color: isDark \? const Color\(0xFF2E2E2E\) : const Color\(0xFFD8D9EC\),\r?\n                      \),\r?\n                      Expanded\(\r?\n                        child: _StatItem\(\r?\n                          value: '\$\{_followersCount \+ _followingCount\}',\r?\n                          label: 'Relations',\r?\n                          icon: Icons\.people_alt_rounded,\r?\n                        \),\r?\n                      \),\r?\n                    \],\r?\n                  \),\r?\n                \),\r?\n              \),/g;

const replacement = `              // Unified stats bar: Posts | Reservations | Relations
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8F6),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        value: '$_postsCount',
                        label: 'Posts',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFD8D9EC),
                    ),
                    Expanded(
                      child: _StatItem(
                        value: '$_bookingsCount',
                        label: 'Reservations',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFD8D9EC),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          final userId = (_user?.id ?? '').toString();
                          if (userId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RelationsScreen(userId: userId),
                              ),
                            );
                          }
                        },
                        child: _StatItem(
                          value: '\${_followersCount + _followingCount}',
                          label: 'Relations',
                          icon: Icons.people_alt_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),`;

content = content.replace(regex, replacement);
fs.writeFileSync(path, content, 'utf8');
console.log('Fixed tourist profile tab');
