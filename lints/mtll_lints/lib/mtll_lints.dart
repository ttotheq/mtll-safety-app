import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _MtllLintsPlugin();

class _MtllLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
    CrossTenantQuery(),
  ];
}

/// EXECUTION-PLAN §6.3.5 — flags any Drift `select()` or `delete()` on a
/// league-scoped table whose enclosing query expression carries no
/// `leagueId` filter (`tenantFilter(...)` or a direct `leagueId` reference).
///
/// Intentional unfiltered reads (the fetch-then-`assertLeagueScope` audit
/// pattern) must carry an explicit `// ignore: cross_tenant_query` with a
/// justification.
class CrossTenantQuery extends DartLintRule {
  const CrossTenantQuery() : super(code: _code);

  static const _code = LintCode(
    name: 'cross_tenant_query',
    problemMessage:
        'Drift select()/delete() on a league-scoped table without a '
        'leagueId filter (EXECUTION-PLAN §6.3.5).',
    correctionMessage:
        'Add ..where(tenantFilter(<table>.leagueId)) or an explicit '
        'leagueId predicate, or suppress with an `// ignore: '
        'cross_tenant_query` comment justifying the unfiltered access.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  // AppDatabase getter names for every table carrying a league_id column.
  // `leagues` itself is the tenant root and is excluded.
  static const _leagueScopedTables = {
    'seasons',
    'divisions',
    'teams',
    'volunteers',
    'roles',
    'volunteerAssignments',
    'clearanceTypes',
    'roleClearanceRequirements',
    'volunteerClearances',
    'evidenceFiles',
    'exemptions',
    'activityLogs',
    'users',
    'auditLogs',
    'auditLogChains',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Test files verify cross-tenant and audit behavior by querying the
    // database directly; the rule guards production code and fixtures.
    if (resolver.path.endsWith('_test.dart')) {
      return;
    }

    context.registry.addMethodInvocation((node) {
      final methodName = node.methodName.name;
      if (methodName != 'select' && methodName != 'delete') {
        return;
      }

      final arguments = node.argumentList.arguments;
      if (arguments.isEmpty) {
        return;
      }

      final tableGetter = _trailingIdentifier(arguments.first);
      if (!_leagueScopedTables.contains(tableGetter)) {
        return;
      }

      final querySource = _outermostExpression(node).toSource();
      if (querySource.contains('tenantFilter') ||
          querySource.contains('leagueId')) {
        return;
      }

      reporter.atNode(node, _code);
    });
  }

  String? _trailingIdentifier(Expression expression) {
    if (expression is PrefixedIdentifier) {
      return expression.identifier.name;
    }
    if (expression is PropertyAccess) {
      return expression.propertyName.name;
    }
    if (expression is SimpleIdentifier) {
      return expression.name;
    }
    return null;
  }

  // Climbs to the outermost enclosing expression so cascades such as
  // `(db.select(db.teams)..where(...)).get()` are inspected as one unit.
  AstNode _outermostExpression(AstNode node) {
    var current = node;
    while (current.parent is Expression) {
      current = current.parent!;
    }
    return current;
  }
}
