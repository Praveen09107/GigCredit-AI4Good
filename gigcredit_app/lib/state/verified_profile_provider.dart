import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/verified_profile.dart';

final verifiedProfileProvider =
    StateProvider<VerifiedProfile>((ref) => const VerifiedProfile());

