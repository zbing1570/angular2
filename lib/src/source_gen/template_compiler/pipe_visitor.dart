import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:angular2/src/compiler/compile_metadata.dart';
import 'package:angular2/src/source_gen/common/annotation_matcher.dart';
import 'package:angular2/src/source_gen/template_compiler/compile_metadata.dart';
import 'package:angular2/src/source_gen/template_compiler/dart_object_utils.dart';
import 'package:logging/logging.dart';

class PipeVisitor extends RecursiveElementVisitor<CompilePipeMetadata> {
  final Logger _logger;

  PipeVisitor(this._logger);

  @override
  CompilePipeMetadata visitClassElement(ClassElement element) {
    for (ElementAnnotation annotation in element.metadata) {
      if (isPipe(annotation)) {
        return _createPipeMetadata(annotation, element);
      }
    }
    return null;
  }

  CompilePipeMetadata _createPipeMetadata(
      ElementAnnotation annotation, ClassElement element) {
    var value = annotation.computeConstantValue();
    return new CompilePipeMetadata(
        type: element.accept(new CompileTypeMetadataVisitor(_logger)),
        name: coerceString(value, 'name'),
        pure: coerceBool(value, 'pure', defaultTo: true),
        lifecycleHooks: []);
  }
}
