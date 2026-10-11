class CategoryModel {
  final int? id;
  final String name;
  final String? icon;
  final String? color;

  CategoryModel({
    this.id,
    required this.name,
    this.icon,
    this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
    );
  }
}

class SubCategoryModel {
  final int? id;
  final String categoryName;
  final String subCategoryName;

  SubCategoryModel({
    this.id,
    required this.categoryName,
    required this.subCategoryName,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_name': categoryName,
      'sub_category_name': subCategoryName,
    };
  }

  factory SubCategoryModel.fromMap(Map<String, dynamic> map) {
    return SubCategoryModel(
      id: map['id'] as int?,
      categoryName: map['category_name'] as String,
      subCategoryName: map['sub_category_name'] as String,
    );
  }
}
