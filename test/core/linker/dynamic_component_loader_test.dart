@TestOn('browser && !js')
library angular2.test.core.linker.dynamic_component_loader_test;

import 'dart:html';

import 'package:angular2/core.dart' show Injector, ViewContainerRef, ViewChild;
import 'package:angular2/src/core/linker/dynamic_component_loader.dart'
    show DynamicComponentLoader;
import 'package:angular2/src/core/linker/element_ref.dart' show ElementRef;
import 'package:angular2/src/core/metadata.dart' show Component;
import 'package:angular2/src/facade/exceptions.dart' show BaseException;
import 'package:angular2/src/platform/dom/dom_tokens.dart' show DOCUMENT;
import 'package:angular2/testing_internal.dart';
import 'package:test/test.dart';

void main() {
  group('DynamicComponentLoader', () {
    group('loading next to a location', () {
      test('should work', () async {
        return inject(
            [DynamicComponentLoader, TestComponentBuilder, AsyncTestCompleter],
            (DynamicComponentLoader loader, TestComponentBuilder tcb,
                AsyncTestCompleter completer) {
          tcb.createAsync(MyComp).then((tc) {
            tc.detectChanges();
            loader
                .loadNextToLocation(
                    DynamicallyLoaded, tc.componentInstance.viewContainerRef)
                .then((ref) {
              expect(tc.debugElement.nativeElement,
                  hasTextContent('DynamicallyLoaded;'));
              completer.done();
            });
          });
        });
      });
      test('should return a disposable component ref', () async {
        return inject(
            [DynamicComponentLoader, TestComponentBuilder, AsyncTestCompleter],
            (DynamicComponentLoader loader, TestComponentBuilder tcb,
                AsyncTestCompleter completer) {
          tcb.createAsync(MyComp).then((tc) {
            tc.detectChanges();
            loader
                .loadNextToLocation(
                    DynamicallyLoaded, tc.componentInstance.viewContainerRef)
                .then((ref) {
              loader
                  .loadNextToLocation(
                      DynamicallyLoaded2, tc.componentInstance.viewContainerRef)
                  .then((ref2) {
                expect(tc.debugElement.nativeElement,
                    hasTextContent('DynamicallyLoaded;DynamicallyLoaded2;'));
                ref2.destroy();
                expect(tc.debugElement.nativeElement,
                    hasTextContent('DynamicallyLoaded;'));
                completer.done();
              });
            });
          });
        });
      });
      test('should update host properties', () async {
        return inject(
            [DynamicComponentLoader, TestComponentBuilder, AsyncTestCompleter],
            (DynamicComponentLoader loader, TestComponentBuilder tcb,
                AsyncTestCompleter completer) {
          tcb.createAsync(MyComp).then((tc) {
            tc.detectChanges();
            loader
                .loadNextToLocation(DynamicallyLoadedWithHostProps,
                    tc.componentInstance.viewContainerRef)
                .then((ref) {
              ref.instance.id = 'new value';
              tc.detectChanges();
              var newlyInsertedElement =
                  tc.debugElement.childNodes[1].nativeNode;
              expect(((newlyInsertedElement as dynamic)).id, 'new value');
              completer.done();
            });
          });
        });
      });
      test(
          'should leave the view tree in a consistent state if hydration fails',
          () async {
        return inject(
            [DynamicComponentLoader, TestComponentBuilder, AsyncTestCompleter],
            (DynamicComponentLoader loader, TestComponentBuilder tcb,
                AsyncTestCompleter completer) {
          tcb.createAsync(MyComp).then((ComponentFixture tc) {
            tc.detectChanges();
            loader
                .loadNextToLocation(DynamicallyLoadedThrows,
                    tc.componentInstance.viewContainerRef)
                .catchError((error) {
              expect(error.message, contains('ThrownInConstructor'));
              // should not throw.
              tc.detectChanges();
              completer.done();
              return null;
            });
          });
        });
      });
      test('should allow to pass projectable nodes', () async {
        return inject(
            [DynamicComponentLoader, TestComponentBuilder, AsyncTestCompleter],
            (DynamicComponentLoader loader, TestComponentBuilder tcb,
                AsyncTestCompleter completer) {
          tcb.createAsync(MyComp).then((tc) {
            tc.detectChanges();
            loader.loadNextToLocation(DynamicallyLoadedWithNgContent,
                tc.componentInstance.viewContainerRef, null, [
              [new Text('hello')]
            ]).then((ref) {
              tc.detectChanges();
              var newlyInsertedElement =
                  tc.debugElement.childNodes[1].nativeNode;
              expect(newlyInsertedElement, hasTextContent('dynamic(hello)'));
              completer.done();
            });
          });
        });
      });
      test('should not throw if not enough projectable nodes are passed in',
          () async {
        return inject(
            [DynamicComponentLoader, TestComponentBuilder, AsyncTestCompleter],
            (DynamicComponentLoader loader, TestComponentBuilder tcb,
                AsyncTestCompleter completer) {
          tcb.createAsync(MyComp).then((tc) {
            tc.detectChanges();
            loader.loadNextToLocation(DynamicallyLoadedWithNgContent,
                tc.componentInstance.viewContainerRef, null, []).then((_) {
              completer.done();
            });
          });
        });
      });
    });
    group('loadAsRoot', () {
      test('should allow to create, update and destroy components', () async {
        return inject(
            [AsyncTestCompleter, DynamicComponentLoader, DOCUMENT, Injector],
            (AsyncTestCompleter completer, DynamicComponentLoader loader, doc,
                Injector injector) {
          var rootEl = createRootElement(doc, 'child-cmp');
          (doc as HtmlDocument).body.append(rootEl);
          loader.loadAsRoot(ChildComp, injector).then((componentRef) {
            var el = new ComponentFixture(componentRef);
            expect(rootEl.parentNode, doc.body);
            el.detectChanges();
            expect(rootEl, hasTextContent('hello'));
            componentRef.instance.ctxProp = 'new';
            el.detectChanges();
            expect(rootEl, hasTextContent('new'));
            componentRef.destroy();
            expect(rootEl.parentNode, isNull);
            completer.done();
          });
        });
      });
      test('should allow to pass projectable nodes', () async {
        return inject(
            [AsyncTestCompleter, DynamicComponentLoader, DOCUMENT, Injector],
            (AsyncTestCompleter completer, DynamicComponentLoader loader, doc,
                Injector injector) {
          var rootEl = createRootElement(doc, 'dummy');
          (doc as HtmlDocument).body.append(rootEl);
          loader.loadAsRoot(DynamicallyLoadedWithNgContent, injector,
              projectableNodes: [
                [new Text('hello')]
              ]).then((_) {
            expect(rootEl, hasTextContent('dynamic(hello)'));
            completer.done();
          });
        });
      });
    });
  });
}

dynamic createRootElement(HtmlDocument doc, String name) {
  var nodes = doc.querySelectorAll(name);
  for (var i = 0; i < nodes.length; i++) {
    nodes[i].remove();
  }
  Element rootEl = new Element.tag(name);
  doc.body.append(rootEl);
  return rootEl;
}

typedef bool _Predicate<T>(T item);

_Predicate<DebugElement> filterByDirective(Type type) {
  return (debugElement) {
    return !identical(debugElement.providerTokens.indexOf(type), -1);
  };
}

@Component(selector: 'child-cmp', template: '{{ctxProp}}')
class ChildComp {
  ElementRef elementRef;
  String ctxProp;
  ChildComp(this.elementRef) {
    this.ctxProp = 'hello';
  }
}

@Component(selector: 'dummy', template: 'DynamicallyLoaded;')
class DynamicallyLoaded {}

@Component(selector: 'dummy', template: 'DynamicallyLoaded;')
class DynamicallyLoadedThrows {
  DynamicallyLoadedThrows() {
    throw new BaseException('ThrownInConstructor');
  }
}

@Component(selector: 'dummy', template: 'DynamicallyLoaded2;')
class DynamicallyLoaded2 {}

@Component(
    selector: 'dummy',
    host: const {'[id]': 'id'},
    template: 'DynamicallyLoadedWithHostProps;')
class DynamicallyLoadedWithHostProps {
  String id;
  DynamicallyLoadedWithHostProps() {
    this.id = 'default';
  }
}

@Component(selector: 'dummy', template: 'dynamic(<ng-content></ng-content>)')
class DynamicallyLoadedWithNgContent {
  String id;
  DynamicallyLoadedWithNgContent() {
    this.id = 'default';
  }
}

@Component(
    selector: 'my-comp', directives: const [], template: '<div #loc></div>')
class MyComp {
  bool ctxBoolProp;
  @ViewChild('loc', read: ViewContainerRef)
  ViewContainerRef viewContainerRef;
  MyComp() {
    this.ctxBoolProp = false;
  }
}
