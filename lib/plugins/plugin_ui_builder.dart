import 'package:flutter/material.dart';
import 'plugin_model.dart';
import 'plugin_service.dart';

class PluginUIBuilder {
  final PluginService _pluginService = PluginService();

  Widget buildScreen(PluginScreen screen, BuildContext context) {
    return Scaffold(
      appBar: screen.title != null ? AppBar(title: Text(screen.title!)) : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: screen.widgets.map((w) => buildWidget(w, context)).toList(),
        ),
      ),
    );
  }

  Widget buildWidget(PluginScreenWidget widget, BuildContext context) {
    final theme = Theme.of(context);

    Widget result;

    switch (widget.type) {
      case PluginWidgetType.text:
        result = _buildText(widget, theme);
        break;
      case PluginWidgetType.button:
        result = _buildButton(widget, context);
        break;
      case PluginWidgetType.image:
        result = _buildImage(widget);
        break;
      case PluginWidgetType.container:
        result = _buildContainer(widget, context);
        break;
      case PluginWidgetType.column:
        result = _buildColumn(widget, context);
        break;
      case PluginWidgetType.row:
        result = _buildRow(widget, context);
        break;
      case PluginWidgetType.list:
        result = _buildList(widget, context);
        break;
      case PluginWidgetType.card:
        result = _buildCard(widget, context);
        break;
      case PluginWidgetType.divider:
        result = const Divider();
        break;
      case PluginWidgetType.spacer:
        final height = (widget.properties['height'] as num?)?.toDouble() ?? 16;
        result = SizedBox(height: height);
        break;
      case PluginWidgetType.icon:
        result = _buildIcon(widget, theme);
        break;
    }

    if (widget.onTap != null) {
      result = GestureDetector(
        onTap: () => _pluginService.executeAction(widget.onTap!, context),
        child: result,
      );
    }

    return result;
  }

  Widget _buildText(PluginScreenWidget widget, ThemeData theme) {
    final text = widget.properties['text'] as String? ?? '';
    final style = widget.properties['style'] as String?;

    TextStyle textStyle;
    switch (style) {
      case 'headline':
        textStyle = theme.textTheme.headlineMedium!;
        break;
      case 'title':
        textStyle = theme.textTheme.titleLarge!;
        break;
      case 'subtitle':
        textStyle = theme.textTheme.titleMedium!;
        break;
      case 'caption':
        textStyle = theme.textTheme.bodySmall!;
        break;
      default:
        textStyle = theme.textTheme.bodyMedium!;
    }

    if (widget.properties['color'] != null) {
      textStyle = textStyle.copyWith(
        color: _parseColor(widget.properties['color']),
      );
    }
    if (widget.properties['bold'] == true) {
      textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: (widget.properties['paddingV'] as num?)?.toDouble() ?? 4,
      ),
      child: Text(text, style: textStyle),
    );
  }

  Widget _buildButton(PluginScreenWidget widget, BuildContext context) {
    final text = widget.properties['text'] as String? ?? 'Button';
    final style = widget.properties['style'] as String?;
    final icon = widget.properties['icon'] as String?;

    VoidCallback? onPressed;
    if (widget.onTap != null) {
      onPressed = () => _pluginService.executeAction(widget.onTap!, context);
    }

    Widget iconWidget = icon != null
        ? Icon(_getIconData(icon))
        : const SizedBox();

    switch (style) {
      case 'outlined':
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: iconWidget,
          label: Text(text),
        );
      case 'text':
        return TextButton.icon(
          onPressed: onPressed,
          icon: iconWidget,
          label: Text(text),
        );
      default:
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: iconWidget,
          label: Text(text),
        );
    }
  }

  Widget _buildImage(PluginScreenWidget widget) {
    final src = widget.properties['src'] as String? ?? '';
    final width = (widget.properties['width'] as num?)?.toDouble();
    final height = (widget.properties['height'] as num?)?.toDouble();
    final fit = widget.properties['fit'] as String?;

    BoxFit boxFit;
    switch (fit) {
      case 'cover':
        boxFit = BoxFit.cover;
        break;
      case 'contain':
        boxFit = BoxFit.contain;
        break;
      case 'fill':
        boxFit = BoxFit.fill;
        break;
      default:
        boxFit = BoxFit.contain;
    }

    if (src.startsWith('http')) {
      return Image.network(src, width: width, height: height, fit: boxFit);
    } else {
      return Image.asset(src, width: width, height: height, fit: boxFit);
    }
  }

  Widget _buildContainer(PluginScreenWidget widget, BuildContext context) {
    final padding = (widget.properties['padding'] as num?)?.toDouble() ?? 0;
    final color = widget.properties['color'] != null
        ? _parseColor(widget.properties['color'])
        : null;
    final borderRadius =
        (widget.properties['borderRadius'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: widget.children != null && widget.children!.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children!
                  .map((c) => buildWidget(c, context))
                  .toList(),
            )
          : null,
    );
  }

  Widget _buildColumn(PluginScreenWidget widget, BuildContext context) {
    return Column(
      crossAxisAlignment: _getCrossAxisAlignment(
        widget.properties['crossAxis'],
      ),
      mainAxisAlignment: _getMainAxisAlignment(widget.properties['mainAxis']),
      children:
          widget.children?.map((c) => buildWidget(c, context)).toList() ?? [],
    );
  }

  Widget _buildRow(PluginScreenWidget widget, BuildContext context) {
    return Row(
      crossAxisAlignment: _getCrossAxisAlignment(
        widget.properties['crossAxis'],
      ),
      mainAxisAlignment: _getMainAxisAlignment(widget.properties['mainAxis']),
      children:
          widget.children?.map((c) => buildWidget(c, context)).toList() ?? [],
    );
  }

  Widget _buildList(PluginScreenWidget widget, BuildContext context) {
    return Column(
      children:
          widget.children?.map((c) => buildWidget(c, context)).toList() ?? [],
    );
  }

  Widget _buildCard(PluginScreenWidget widget, BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
        vertical: (widget.properties['marginV'] as num?)?.toDouble() ?? 8,
      ),
      child: Padding(
        padding: EdgeInsets.all(
          (widget.properties['padding'] as num?)?.toDouble() ?? 16,
        ),
        child: widget.children != null && widget.children!.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children!
                    .map((c) => buildWidget(c, context))
                    .toList(),
              )
            : null,
      ),
    );
  }

  Widget _buildIcon(PluginScreenWidget widget, ThemeData theme) {
    final name = widget.properties['name'] as String? ?? 'help';
    final size = (widget.properties['size'] as num?)?.toDouble() ?? 24;
    final color = widget.properties['color'] != null
        ? _parseColor(widget.properties['color'])
        : null;

    return Icon(_getIconData(name), size: size, color: color);
  }

  Widget buildSettingsItem(PluginItem item, BuildContext context) {
    switch (item.type) {
      case PluginItemType.button:
        return ListTile(
          leading: item.icon != null ? Icon(_getIconData(item.icon!)) : null,
          title: Text(item.title ?? ''),
          subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: item.action != null
              ? () => _pluginService.executeAction(item.action!, context)
              : null,
        );

      case PluginItemType.toggle:
        return _PluginToggleTile(item: item);

      case PluginItemType.slider:
        return _PluginSliderTile(item: item);

      case PluginItemType.text:
        return ListTile(
          title: Text(item.title ?? ''),
          subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
        );

      case PluginItemType.divider:
        return const Divider();

      case PluginItemType.navigation:
        return ListTile(
          leading: item.icon != null ? Icon(_getIconData(item.icon!)) : null,
          title: Text(item.title ?? ''),
          subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (item.children != null && item.children!.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _PluginSubScreen(
                    title: item.title ?? '',
                    items: item.children!,
                  ),
                ),
              );
            }
          },
        );
    }
  }

  Color _parseColor(dynamic colorValue) {
    if (colorValue is String) {
      if (colorValue.startsWith('#')) {
        final hex = colorValue.replaceFirst('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      }
      switch (colorValue) {
        case 'primary':
          return Colors.blue;
        case 'secondary':
          return Colors.grey;
        case 'error':
          return Colors.red;
        case 'success':
          return Colors.green;
        default:
          return Colors.black;
      }
    }
    return Colors.black;
  }

  IconData _getIconData(String name) {
    const icons = {
      'settings': Icons.settings,
      'home': Icons.home,
      'person': Icons.person,
      'chat': Icons.chat,
      'search': Icons.search,
      'add': Icons.add,
      'delete': Icons.delete,
      'edit': Icons.edit,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'share': Icons.share,
      'download': Icons.download,
      'upload': Icons.upload,
      'refresh': Icons.refresh,
      'info': Icons.info,
      'help': Icons.help,
      'warning': Icons.warning,
      'error': Icons.error,
      'check': Icons.check,
      'close': Icons.close,
      'arrow_back': Icons.arrow_back,
      'arrow_forward': Icons.arrow_forward,
      'menu': Icons.menu,
      'more_vert': Icons.more_vert,
      'notifications': Icons.notifications,
      'lock': Icons.lock,
      'visibility': Icons.visibility,
      'visibility_off': Icons.visibility_off,
      'palette': Icons.palette,
      'extension': Icons.extension,
      'code': Icons.code,
      'bug_report': Icons.bug_report,
      'speed': Icons.speed,
      'memory': Icons.memory,
      'storage': Icons.storage,
      'wifi': Icons.wifi,
      'bluetooth': Icons.bluetooth,
      'battery_full': Icons.battery_full,
      'brightness_6': Icons.brightness_6,
      'dark_mode': Icons.dark_mode,
      'light_mode': Icons.light_mode,
    };
    return icons[name] ?? Icons.help_outline;
  }

  CrossAxisAlignment _getCrossAxisAlignment(String? value) {
    switch (value) {
      case 'start':
        return CrossAxisAlignment.start;
      case 'end':
        return CrossAxisAlignment.end;
      case 'center':
        return CrossAxisAlignment.center;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      default:
        return CrossAxisAlignment.start;
    }
  }

  MainAxisAlignment _getMainAxisAlignment(String? value) {
    switch (value) {
      case 'start':
        return MainAxisAlignment.start;
      case 'end':
        return MainAxisAlignment.end;
      case 'center':
        return MainAxisAlignment.center;
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      case 'spaceAround':
        return MainAxisAlignment.spaceAround;
      case 'spaceEvenly':
        return MainAxisAlignment.spaceEvenly;
      default:
        return MainAxisAlignment.start;
    }
  }
}

class _PluginToggleTile extends StatefulWidget {
  final PluginItem item;

  const _PluginToggleTile({required this.item});

  @override
  State<_PluginToggleTile> createState() => _PluginToggleTileState();
}

class _PluginToggleTileState extends State<_PluginToggleTile> {
  late bool _value;
  final _pluginService = PluginService();

  @override
  void initState() {
    super.initState();
    _value = _pluginService.getPluginValue(
      widget.item.key ?? '',
      widget.item.defaultValue ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(widget.item.title ?? ''),
      subtitle: widget.item.subtitle != null
          ? Text(widget.item.subtitle!)
          : null,
      value: _value,
      onChanged: (v) {
        setState(() => _value = v);
        _pluginService.setPluginValue(widget.item.key ?? '', v);
      },
    );
  }
}

class _PluginSliderTile extends StatefulWidget {
  final PluginItem item;

  const _PluginSliderTile({required this.item});

  @override
  State<_PluginSliderTile> createState() => _PluginSliderTileState();
}

class _PluginSliderTileState extends State<_PluginSliderTile> {
  late double _value;
  final _pluginService = PluginService();

  @override
  void initState() {
    super.initState();
    _value =
        (_pluginService.getPluginValue(
                  widget.item.key ?? '',
                  widget.item.defaultValue ?? widget.item.min ?? 0,
                )
                as num)
            .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(widget.item.title ?? ''),
          subtitle: widget.item.subtitle != null
              ? Text(widget.item.subtitle!)
              : null,
          trailing: Text(_value.toStringAsFixed(0)),
        ),
        Slider(
          value: _value,
          min: widget.item.min ?? 0,
          max: widget.item.max ?? 100,
          divisions: widget.item.divisions,
          onChanged: (v) {
            setState(() => _value = v);
            _pluginService.setPluginValue(widget.item.key ?? '', v);
          },
        ),
      ],
    );
  }
}

class _PluginSubScreen extends StatelessWidget {
  final String title;
  final List<PluginItem> items;

  const _PluginSubScreen({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final builder = PluginUIBuilder();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: items
            .map((item) => builder.buildSettingsItem(item, context))
            .toList(),
      ),
    );
  }
}
