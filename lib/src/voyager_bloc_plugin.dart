import 'package:bloc/bloc.dart';
import 'package:voyager/voyager.dart';

const _KEY_BLOCS = "blocs";
const _KEY_DEFAULT = "default";

class BlocsPluginBuilder {
  var _blocBuilders = <_RepositoryBlocBuilder>[];
  BlocsPluginBuilder
      addBloc<BlocType extends BlocParentType, BlocParentType extends Bloc>(
          VoyagerBlocBuilder<BlocType>? builder) {
    final blocType = _typeOf<BlocType>();
    final blocParentType = _typeOf<BlocParentType>();

    if (blocType.toString() == _typeOf<Bloc>().toString()) {
      throw ArgumentError("BlocType must be a subclass of BlocParentType");
    }

    if (blocParentType.toString() == _typeOf<Bloc>().toString()) {
      throw ArgumentError("BlocParentType must be a subclass of Bloc");
    }

    _blocBuilders
        .add(_RepositoryBlocBuilder(builder, blocType, blocParentType));

    return this;
  }

  BlocsPluginBuilder addBaseBloc<BlocType extends Bloc>(
          VoyagerBlocBuilder<BlocType>? builder) =>
      addBloc<BlocType, BlocType>(builder);

  BlocsPluginBuilder addBuilder(BlocsPluginBuilder other) {
    _blocBuilders.addAll(other._blocBuilders);
    return this;
  }

  BlocsPlugin build() => BlocsPlugin(_blocBuilders);
}

/// Specify config
///
class BlocsPlugin extends VoyagerPlugin{
  final Map<String, _RepositoryBlocBuilder> _builders =
      Map<String, _RepositoryBlocBuilder>();

  BlocsPlugin(List<_RepositoryBlocBuilder> builders) : super(_KEY_BLOCS) {
    builders.forEach((builder) {
      _builders[builder.type.toString()] = builder;
    });
  }

  @override
  void outputFor(VoyagerContext context, config, Voyager output) {
    if (!(config is List<dynamic>)) return;

    final blocRepository = BlocRepository();
    final blocsToDispose = <_Lazy<Bloc>>[];

    config.forEach((blocNode) {
      dynamic blocConfig;
      String key;
      String name = _KEY_DEFAULT;

      if (VoyagerUtils.isTuple(blocNode)) {
        MapEntry<String, dynamic> tuple = VoyagerUtils.tuple(blocNode);
        key = tuple.key;
        blocConfig = tuple.value;
      } else {
        key = blocNode.toString();
      }

      // MyBloc@myName
      if (key.contains("@")) {
        final keySplit = key.split("@");
        if (keySplit.length == 2) {
          key = keySplit[0];
          name = keySplit[1];
        } else {
          throw ArgumentError("Too many @ sings in the key of the Bloc");
        }
      }

      final builder = _builders[key];
      if (builder == null) {
        throw UnimplementedError("No bloc builder for $key");
      }

      _Lazy<Bloc> bloc = _Lazy<Bloc>(
          () => builder.builder!(context, blocConfig, blocRepository));
      blocRepository.add(bloc, name, builder.type, builder.parentType);
      blocsToDispose.add(bloc);
    });

    output[_KEY_BLOCS] = blocRepository;
    output.onDispose(() {
      blocsToDispose.forEach((bloc) {
        if (bloc.isInitalized) {
          bloc.value!.close();
        }
      });
    });
  }
}

typedef VoyagerBlocBuilder<T extends Bloc> = T Function(
    VoyagerContext context, dynamic config, BlocRepository blocRepository);

class _RepositoryBlocBuilder {
  final Type type;
  final Type parentType;
  final VoyagerBlocBuilder? builder;

  _RepositoryBlocBuilder(this.builder, this.type, this.parentType);
}

class BlocRepository {
  /// [parentType][name] map of blocs
  final _blocByType = Map<String, List<_Lazy<Bloc>>>();
  final _blocByParentType = Map<String, List<_Lazy<Bloc>>>();
  final _blocByName = Map<String, List<_Lazy<Bloc>>>();

  void add(_Lazy<Bloc> bloc, String name, Type blocType, Type parentType) {
    String typeStr = blocType.toString();
    String parentTypeStr = parentType.toString();

    if (name != _KEY_DEFAULT) {
      _blocByName[name] = (_blocByName[name] ?? [])..add(bloc);
      return;
    }
    _blocByParentType[parentTypeStr] = (_blocByParentType[parentTypeStr] ?? [])
      ..add(bloc);
    _blocByType[typeStr] = (_blocByType[typeStr] ?? [])..add(bloc);
  }

  T? find<T extends Bloc>({String? name}) {
    if (name != null && name != _KEY_DEFAULT) {
      T? foundBloc;
      _blocByName[name]?.forEach((lazyBloc) {
        // ignore: close_sinks
        final bloc = lazyBloc.value;
        if (bloc is T) {
          foundBloc = bloc;
          return;
        }
      });
      return foundBloc;
    }

    String blocType = _typeOf<T>().toString();
    return _firstOrNull(_blocByType[blocType])?.value ??
        _firstOrNull(_blocByParentType[blocType])?.value;
  }
}

/// Necessary to obtain generic [Type]
/// https://github.com/dart-lang/sdk/issues/11923
Type _typeOf<T>() => T;

dynamic _firstOrNull(List? list) {
  if (list == null || list.isEmpty) return null;
  return list[0];
}

typedef LazyBuilder<T> = T Function();

class _Lazy<T> {
  _Lazy(this.builder);
  T? _value;
  final LazyBuilder<T> builder;

  bool get isInitalized => _value != null;

  T? get value {
    if (_value == null) {
      _value = builder();
    }
    return _value;
  }
}
