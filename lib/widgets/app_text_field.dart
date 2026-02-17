import 'package:flutter/material.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool isPassword;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final Widget? prefix;
  final int? maxLines;
  final int? minLines;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.textInputAction,
    this.isPassword = false,
    this.validator,
    this.onSubmitted,
    this.prefix,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: widget.isPassword ? _obscure : false,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      minLines: widget.isPassword ? 1 : widget.minLines,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefix,
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              )
            : null,
      ),
    );
  }
}