import 'package:mocktail/mocktail.dart';

import 'package:esteticaybellezastrani/features/treatment_execution/domain/repositories/i_treatment_execution_repository.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/repositories/i_treatment_photos_repository.dart';

class MockITreatmentExecutionRepository extends Mock
    implements ITreatmentExecutionRepository {}

class MockITreatmentPhotosRepository extends Mock
    implements ITreatmentPhotosRepository {}