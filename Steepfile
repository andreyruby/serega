# frozen_string_literal: true

D = Steep::Diagnostic

# Checks the public methods of lib/ against their signatures in sig/.
# Internal classes have no signatures, thus the checks of calls and of
# untyped code stay off.
target :lib do
  signature "sig"
  check "lib"

  configure_code_diagnostics(D::Ruby.silent) do |diagnostics|
    [
      D::Ruby::ClassModuleMismatch,
      D::Ruby::DifferentMethodParameterKind,
      D::Ruby::MethodArityMismatch,
      D::Ruby::MethodBodyTypeMismatch,
      D::Ruby::MethodParameterMismatch,
      D::Ruby::MethodReturnTypeAnnotationMismatch,
      D::Ruby::ReturnTypeMismatch,
      D::Ruby::SetterBodyTypeMismatch,
      D::Ruby::SyntaxError
    ].each { |diagnostic| diagnostics[diagnostic] = :error }
  end
end
