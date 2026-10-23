import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HttpError extends StatelessWidget {
  const HttpError({
    required this.errMsg,
    required this.fn,
    this.btnText,
    this.isShowBtn = true,
    super.key,
  });

  final String? errMsg;
  final Function()? fn;
  final String? btnText;
  final bool isShowBtn;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: HttpErrorBox(
        errMsg: errMsg,
        fn: fn,
        btnText: btnText,
        isShowBtn: isShowBtn,
      ),
    );
  }
}

/// 与 [HttpError] 同外观的非 sliver 版本。
///
/// [HttpError] 返回的是 [SliverToBoxAdapter]，只能放进 CustomScrollView/ListView
/// 的 slivers 里；放在 Column/Container 等 box 上下文会直接触发布局崩溃。
class HttpErrorBox extends StatelessWidget {
  const HttpErrorBox({
    required this.errMsg,
    required this.fn,
    this.btnText,
    this.isShowBtn = true,
    this.height = 400,
    super.key,
  });

  final String? errMsg;
  final Function()? fn;
  final String? btnText;
  final bool isShowBtn;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            "assets/images/error.svg",
            height: 200,
          ),
          const SizedBox(height: 30),
          Text(
            errMsg ?? '请求异常',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 20),
          if (isShowBtn && fn != null)
            FilledButton.tonal(
              onPressed: () {
                fn!();
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith((states) {
                  return Theme.of(context).colorScheme.primary.withAlpha(20);
                }),
              ),
              child: Text(
                btnText ?? '点击重试',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}
