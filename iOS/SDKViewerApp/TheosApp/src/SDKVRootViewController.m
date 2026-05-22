#import "SDKVRootViewController.h"
#import "SDKVProjectStore.h"
#import "SDKVPointerGenerator.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface SDKVRootViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) SDKVProjectStore *store;
@property (nonatomic, copy) NSString *currentProject;
@property (nonatomic, strong) NSDictionary *currentRecord;
@property (nonatomic, strong) NSDictionary *currentPackage;
@property (nonatomic, strong) NSDictionary *currentType;

@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *packageButton;
@property (nonatomic, strong) UILabel *packageSummaryLabel;
@property (nonatomic, strong) UIButton *typeButton;
@property (nonatomic, strong) UIButton *relatedButton;
@property (nonatomic, strong) UILabel *typeMetadataLabel;
@property (nonatomic, strong) UISegmentedControl *detailModeControl;
@property (nonatomic, strong) UITextView *sourceView;
@property (nonatomic, strong) UITextField *baseField;
@property (nonatomic, strong) UITextField *offsetsField;
@property (nonatomic, strong) UITextField *typeField;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextView *pointerOutputView;
@end

@implementation SDKVRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"SDK Viewer";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.store = [[SDKVProjectStore alloc] init];

    UIBarButtonItem *createItem = [[UIBarButtonItem alloc] initWithTitle:@"New" style:UIBarButtonItemStylePlain target:self action:@selector(createProjectTapped)];
    UIBarButtonItem *loadItem = [[UIBarButtonItem alloc] initWithTitle:@"Load" style:UIBarButtonItemStylePlain target:self action:@selector(loadProjectTapped)];
    UIBarButtonItem *importItem = [[UIBarButtonItem alloc] initWithTitle:@"Import ZIP" style:UIBarButtonItemStylePlain target:self action:@selector(importZipTapped)];
    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(closeProjectTapped)];
    self.navigationItem.leftBarButtonItems = @[createItem, loadItem];
    self.navigationItem.rightBarButtonItems = @[importItem, closeItem];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(16, 16, self.view.bounds.size.width - 32, 1000)];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [scroll addSubview:container];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, container.bounds.size.width, 44)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.statusLabel.numberOfLines = 3;
    self.statusLabel.text = @"Create or load a local project to start.";
    [container addSubview:self.statusLabel];

    self.packageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.packageButton.frame = CGRectMake(0, 60, container.bounds.size.width, 34);
    self.packageButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.packageButton setTitle:@"Select Package" forState:UIControlStateNormal];
    [self.packageButton addTarget:self action:@selector(selectPackageTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:self.packageButton];

    self.packageSummaryLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 96, container.bounds.size.width, 18)];
    self.packageSummaryLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.packageSummaryLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.packageSummaryLabel.textColor = [UIColor secondaryLabelColor];
    [container addSubview:self.packageSummaryLabel];

    self.typeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.typeButton.frame = CGRectMake(0, 122, container.bounds.size.width, 34);
    self.typeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.typeButton setTitle:@"Select Type" forState:UIControlStateNormal];
    [self.typeButton addTarget:self action:@selector(selectTypeTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:self.typeButton];

    self.relatedButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.relatedButton.frame = CGRectMake(container.bounds.size.width - 132, 122, 132, 34);
    self.relatedButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.relatedButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [self.relatedButton setTitle:@"Relations" forState:UIControlStateNormal];
    [self.relatedButton addTarget:self action:@selector(showRelationsTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:self.relatedButton];

    self.typeMetadataLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 160, container.bounds.size.width, 48)];
    self.typeMetadataLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.typeMetadataLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.typeMetadataLabel.textColor = [UIColor secondaryLabelColor];
    self.typeMetadataLabel.numberOfLines = 3;
    [container addSubview:self.typeMetadataLabel];

    self.detailModeControl = [[UISegmentedControl alloc] initWithItems:@[@"Source", @"Fields", @"Graph"]];
    self.detailModeControl.frame = CGRectMake(0, 214, container.bounds.size.width, 32);
    self.detailModeControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.detailModeControl.selectedSegmentIndex = 0;
    [self.detailModeControl addTarget:self action:@selector(detailModeChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.detailModeControl];

    UILabel *sourceTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 254, container.bounds.size.width, 20)];
    sourceTitle.text = @"Type Detail";
    sourceTitle.font = [UIFont boldSystemFontOfSize:16];
    [container addSubview:sourceTitle];

    self.sourceView = [[UITextView alloc] initWithFrame:CGRectMake(0, 278, container.bounds.size.width, 212)];
    self.sourceView.editable = NO;
    self.sourceView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.sourceView.text = @"Import an SDK ZIP and choose Browse to navigate package/type source.";
    [container addSubview:self.sourceView];

    UILabel *pointerTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 502, container.bounds.size.width, 20)];
    pointerTitle.text = @"Pointer Chain Generator";
    pointerTitle.font = [UIFont boldSystemFontOfSize:16];
    [container addSubview:pointerTitle];

    self.baseField = [self makeField:@"Base expression (e.g. baseAddress)" y:530 width:container.bounds.size.width];
    self.baseField.text = @"baseAddress";
    [container addSubview:self.baseField];

    self.offsetsField = [self makeField:@"Offsets (comma separated: 0x30, 0x18, 0x8)" y:570 width:container.bounds.size.width];
    self.offsetsField.text = @"0x0";
    [container addSubview:self.offsetsField];

    self.typeField = [self makeField:@"Result type" y:610 width:container.bounds.size.width];
    self.typeField.text = @"uintptr_t";
    [container addSubview:self.typeField];

    self.nameField = [self makeField:@"Result variable name" y:650 width:container.bounds.size.width];
    self.nameField.text = @"resultPtr";
    [container addSubview:self.nameField];

    UIButton *generateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    generateBtn.frame = CGRectMake(0, 690, 160, 36);
    [generateBtn setTitle:@"Generate C++" forState:UIControlStateNormal];
    [generateBtn addTarget:self action:@selector(generatePointerTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:generateBtn];

    self.pointerOutputView = [[UITextView alloc] initWithFrame:CGRectMake(0, 734, container.bounds.size.width, 220)];
    self.pointerOutputView.editable = NO;
    self.pointerOutputView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    [container addSubview:self.pointerOutputView];

    container.frame = CGRectMake(16, 16, self.view.bounds.size.width - 32, 970);
    scroll.contentSize = CGSizeMake(self.view.bounds.size.width, 1010);
}

- (UITextField *)makeField:(NSString *)placeholder y:(CGFloat)y width:(CGFloat)width {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, y, width, 34)];
    field.placeholder = placeholder;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    return field;
}

- (void)createProjectTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Create Project" message:@"Enter a project name" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Project Name";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = alert.textFields.firstObject.text ?: @"";
        NSError *error = nil;
        NSDictionary *record = [self.store createProjectNamed:name error:&error];
        if (!record || error) {
            [self showError:error.localizedDescription ?: @"Failed to create project"];
            return;
        }
        self.currentProject = record[@"metadata"][@"name"];
        self.currentRecord = record;
        [self selectPackage:nil];
        [self refreshStatus];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)loadProjectTapped {
    NSError *error = nil;
    NSArray<NSString *> *projects = [self.store listProjects:&error];
    if (error) {
        [self showError:error.localizedDescription];
        return;
    }
    if (projects.count == 0) {
        [self showError:@"No existing projects found"];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Load Project" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *name in projects) {
        [sheet addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSError *loadError = nil;
            NSDictionary *record = [self.store loadProjectNamed:name error:&loadError];
            if (!record || loadError) {
                [self showError:loadError.localizedDescription ?: @"Failed to load project"];
                return;
            }
            self.currentProject = name;
            self.currentRecord = record;
            [self selectPackage:[self firstPackageFromRecord:record]];
            [self refreshStatus];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)importZipTapped {
    if (self.currentProject.length == 0) {
        [self showError:@"Create or load a project first"];
        return;
    }

    UIDocumentPickerViewController *picker;
    if (@available(iOS 14.0, *)) {
        UTType *zipType = [UTType typeWithIdentifier:@"public.zip-archive"];
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[zipType ?: UTTypeData] asCopy:YES];
    } else {
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.zip-archive"] inMode:UIDocumentPickerModeImport];
    }
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)selectPackageTapped {
    NSArray *packages = self.currentRecord[@"dump"][@"packages"];
    if (packages.count == 0) {
        [self showError:@"No parsed packages found. Import a ZIP first."];
        return;
    }

    UIAlertController *pkgSheet = [UIAlertController alertControllerWithTitle:@"Packages" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *pkg in packages) {
        NSString *pkgName = pkg[@"name"] ?: @"Unknown";
        NSString *title = [NSString stringWithFormat:@"%@ (%@)", pkgName, [self packageSummaryTextForPackage:pkg]];
        [pkgSheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self selectPackage:pkg];
            [self presentTypeBrowserForPackage:pkg];
        }]];
    }
    [pkgSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:pkgSheet sourceView:self.packageButton];
}

- (void)selectTypeTapped {
    if (!self.currentPackage) {
        [self selectPackageTapped];
        return;
    }

    [self presentTypeBrowserForPackage:self.currentPackage];
}

- (void)showRelationsTapped {
    if (!self.currentType) {
        [self showError:@"Select a type first"];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:self.currentType[@"name"] message:@"Navigate inheritance relationships" preferredStyle:UIAlertControllerStyleActionSheet];
    NSDictionary *parent = [self parentTypeForType:self.currentType];
    if (parent) {
        NSString *title = [NSString stringWithFormat:@"Parent: %@", parent[@"name"] ?: @"Unknown"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self selectType:parent];
        }]];
    }

    for (NSDictionary *sibling in [self siblingTypesForType:self.currentType]) {
        NSString *title = [NSString stringWithFormat:@"Sibling: %@", sibling[@"name"] ?: @"Unknown"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self selectType:sibling];
        }]];
    }

    for (NSDictionary *child in [self childTypesForType:self.currentType]) {
        NSString *title = [NSString stringWithFormat:@"Child: %@", child[@"name"] ?: @"Unknown"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self selectType:child];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet sourceView:self.relatedButton];
}

- (void)presentTypeBrowserForPackage:(NSDictionary *)package {
    NSArray *types = package[@"types"] ?: @[];
    if (types.count == 0) {
        [self showError:@"Package has no parsed types"];
        return;
    }

    UIAlertController *typeSheet = [UIAlertController alertControllerWithTitle:package[@"name"] message:@"Select a type" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *type in [self orderedTypesForPackage:package]) {
        NSString *title = [self typeSelectionTitle:type];
        [typeSheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self selectType:type];
        }]];
    }
    [typeSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:typeSheet sourceView:self.typeButton];
}

- (void)generatePointerTapped {
    NSArray<NSNumber *> *offsets = [SDKVPointerGenerator parseOffsetsFromText:self.offsetsField.text ?: @""];
    self.pointerOutputView.text = [SDKVPointerGenerator generateCPPWithBaseExpression:(self.baseField.text ?: @"baseAddress")
                                                                               offsets:offsets
                                                                            resultType:(self.typeField.text ?: @"uintptr_t")
                                                                            resultName:(self.nameField.text ?: @"resultPtr")];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    NSURL *zipURL = urls.firstObject;
    if (!zipURL) {
        [self showError:@"No ZIP selected"];
        return;
    }

    NSError *error = nil;
    NSDictionary *record = [self.store importDumpZipAtURL:zipURL toProject:self.currentProject error:&error];
    if (!record || error) {
        [self showError:error.localizedDescription ?: @"Import failed"];
        return;
    }

    self.currentRecord = record;
    [self selectPackage:[self firstPackageFromRecord:record]];
    [self refreshStatus];
}

- (void)refreshStatus {
    NSDictionary *metadata = self.currentRecord[@"metadata"];
    NSArray *packages = self.currentRecord[@"dump"][@"packages"] ?: @[];
    NSString *projectName = metadata[@"name"] ?: @"-";
    NSString *archiveName = metadata[@"sourceArchiveName"] ?: @"No archive imported";
    self.statusLabel.text = [NSString stringWithFormat:@"Project: %@\nPackages: %lu\nArchive: %@", projectName, (unsigned long)packages.count, archiveName];

    NSString *packageName = self.currentPackage[@"name"] ?: @"Select Package";
    [self.packageButton setTitle:packageName forState:UIControlStateNormal];
    self.packageSummaryLabel.text = self.currentPackage ? [self packageSummaryTextForPackage:self.currentPackage] : @"Browse packages after importing a dump.";

    NSString *typeName = self.currentType[@"name"] ?: @"Select Type";
    [self.typeButton setTitle:typeName forState:UIControlStateNormal];
    self.relatedButton.enabled = (self.currentType != nil);
    self.typeMetadataLabel.text = [self typeMetadataText:self.currentType];
    [self updateDetailText];
}

- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeProjectTapped {
    self.currentProject = nil;
    self.currentRecord = nil;
    self.currentPackage = nil;
    self.currentType = nil;
    [self refreshStatus];
}

- (void)selectPackage:(NSDictionary *)package {
    self.currentPackage = package;
    self.currentType = [self firstTypeForPackage:package];
}

- (void)selectType:(NSDictionary *)type {
    self.currentType = type;
    [self refreshStatus];
}

- (void)detailModeChanged:(UISegmentedControl *)sender {
    (void)sender;
    [self updateDetailText];
}

- (NSDictionary *)firstPackageFromRecord:(NSDictionary *)record {
    NSArray *packages = record[@"dump"][@"packages"];
    if (![packages isKindOfClass:[NSArray class]] || packages.count == 0) {
        return nil;
    }
    return packages.firstObject;
}

- (NSDictionary *)firstTypeForPackage:(NSDictionary *)package {
    NSArray *types = [self orderedTypesForPackage:package];
    return types.firstObject;
}

- (NSArray<NSDictionary *> *)orderedTypesForPackage:(NSDictionary *)package {
    NSArray<NSDictionary *> *types = package[@"types"] ?: @[];
    return [types sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *lhs, NSDictionary *rhs) {
        NSNumber *lhsOrder = lhs[@"sourceOrder"] ?: @0;
        NSNumber *rhsOrder = rhs[@"sourceOrder"] ?: @0;
        NSComparisonResult result = [lhsOrder compare:rhsOrder];
        if (result != NSOrderedSame) {
            return result;
        }
        return [lhs[@"name"] compare:rhs[@"name"]];
    }];
}

- (NSString *)packageSummaryTextForPackage:(NSDictionary *)package {
    NSDictionary *summary = package[@"summary"];
    if ([summary isKindOfClass:[NSDictionary class]]) {
        return [NSString stringWithFormat:@"%@ enums · %@ structs · %@ classes",
                summary[@"enumCount"] ?: @0,
                summary[@"structCount"] ?: @0,
                summary[@"classCount"] ?: @0];
    }

    NSArray *types = package[@"types"] ?: @[];
    NSUInteger enumCount = 0;
    NSUInteger structCount = 0;
    NSUInteger classCount = 0;
    for (NSDictionary *type in types) {
        NSString *kind = type[@"kind"] ?: @"struct";
        if ([kind isEqualToString:@"enum"]) {
            enumCount++;
        } else if ([kind isEqualToString:@"class"]) {
            classCount++;
        } else {
            structCount++;
        }
    }

    return [NSString stringWithFormat:@"%lu enums · %lu structs · %lu classes",
            (unsigned long)enumCount,
            (unsigned long)structCount,
            (unsigned long)classCount];
}

- (NSString *)typeSelectionTitle:(NSDictionary *)type {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *label = type[@"objectLabel"] ?: type[@"kind"] ?: @"Type";
    [parts addObject:[NSString stringWithFormat:@"[%@] %@", label, type[@"name"] ?: @"Unknown"]];
    NSString *parent = type[@"parentTypeName"];
    if (parent.length > 0) {
        [parts addObject:[NSString stringWithFormat:@"inherits %@", parent]];
    }
    return [parts componentsJoinedByString:@" - "];
}

- (NSString *)typeMetadataText:(NSDictionary *)type {
    if (!type) {
        return @"Select a type to inspect source and metadata.";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *objectLabel = type[@"objectLabel"] ?: @"Type";
    NSString *kind = type[@"kind"] ?: @"struct";
    [parts addObject:[NSString stringWithFormat:@"%@ · %@", objectLabel, kind]];

    NSString *parent = type[@"parentTypeName"];
    if (parent.length > 0) {
        [parts addObject:[NSString stringWithFormat:@"Inherits %@", parent]];
    }

    NSMutableArray<NSString *> *sizeParts = [NSMutableArray array];
    NSNumber *sizeBytes = type[@"sizeBytes"];
    if (sizeBytes) {
        [sizeParts addObject:[NSString stringWithFormat:@"Size %@", [self hexStringForNumber:sizeBytes]]];
    }
    NSNumber *inheritedSizeBytes = type[@"inheritedSizeBytes"];
    if (inheritedSizeBytes) {
        [sizeParts addObject:[NSString stringWithFormat:@"Inherited %@", [self hexStringForNumber:inheritedSizeBytes]]];
    }
    if (sizeParts.count > 0) {
        [parts addObject:[sizeParts componentsJoinedByString:@" · "]];
    }

    return [parts componentsJoinedByString:@"\n"];
}

- (NSString *)sourceDisplayTextForType:(NSDictionary *)type {
    if (!type) {
        return @"Import an SDK ZIP, choose a package, then select a type to inspect its source.";
    }

    NSMutableArray<NSString *> *sections = [NSMutableArray array];
    NSString *fullName = type[@"fullName"];
    if (fullName.length > 0) {
        [sections addObject:fullName];
    }
    NSString *body = type[@"body"] ?: @"";
    if (body.length > 0) {
        [sections addObject:body];
    }
    return [sections componentsJoinedByString:@"\n\n"];
}

- (NSString *)fieldsDisplayTextForType:(NSDictionary *)type {
    if (!type) {
        return @"Select a type to inspect its parsed field layout.";
    }

    NSArray<NSDictionary *> *fields = [self orderedFieldsForType:type];
    if (fields.count == 0) {
        return @"No parsed field layout rows were found for this type.";
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSNumber *inheritedSizeBytes = type[@"inheritedSizeBytes"];
    if (inheritedSizeBytes) {
        [lines addObject:[NSString stringWithFormat:@"Inherited layout: %@", [self hexStringForNumber:inheritedSizeBytes]]];
        [lines addObject:@""];
    }

    for (NSDictionary *field in fields) {
        NSString *offset = [self hexStringForNumber:field[@"offsetBytes"] ?: @0];
        NSString *size = [self hexStringForNumber:field[@"sizeBytes"] ?: @0];
        NSString *prefix = [field[@"isPadding"] boolValue] ? @"[Padding] " : @"";
        [lines addObject:[NSString stringWithFormat:@"%@%@  %@  %@", prefix, offset, size, field[@"declaration"] ?: field[@"name"] ?: @"Field"]];
    }

    return [lines componentsJoinedByString:@"\n"];
}

- (NSString *)graphDisplayTextForType:(NSDictionary *)type {
    if (!type) {
        return @"Select a type to inspect its inheritance neighborhood.";
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSArray<NSDictionary *> *ancestors = [self ancestorsForType:type];
    if (ancestors.count > 0) {
        [lines addObject:@"Ancestors"]; 
        for (NSDictionary *ancestor in ancestors) {
            [lines addObject:[NSString stringWithFormat:@"  -> %@", ancestor[@"name"] ?: @"Unknown"]];
        }
        [lines addObject:@""];
    }

    [lines addObject:[NSString stringWithFormat:@"Selected\n  %@", type[@"name"] ?: @"Unknown"]];
    [lines addObject:@""];

    NSArray<NSDictionary *> *siblings = [self siblingTypesForType:type];
    if (siblings.count > 0) {
        [lines addObject:@"Siblings"]; 
        for (NSDictionary *sibling in siblings) {
            [lines addObject:[NSString stringWithFormat:@"  - %@", sibling[@"name"] ?: @"Unknown"]];
        }
        [lines addObject:@""];
    }

    NSArray<NSDictionary *> *children = [self childTypesForType:type];
    [lines addObject:@"Children"];
    if (children.count == 0) {
        [lines addObject:@"  (none)"];
    } else {
        for (NSDictionary *child in children) {
            [lines addObject:[NSString stringWithFormat:@"  -> %@", child[@"name"] ?: @"Unknown"]];
        }
    }

    return [lines componentsJoinedByString:@"\n"];
}

- (void)updateDetailText {
    switch (self.detailModeControl.selectedSegmentIndex) {
        case 1:
            self.sourceView.text = [self fieldsDisplayTextForType:self.currentType];
            break;
        case 2:
            self.sourceView.text = [self graphDisplayTextForType:self.currentType];
            break;
        case 0:
        default:
            self.sourceView.text = [self sourceDisplayTextForType:self.currentType];
            break;
    }
}

- (NSArray<NSDictionary *> *)orderedFieldsForType:(NSDictionary *)type {
    NSArray<NSDictionary *> *fields = type[@"fields"] ?: @[];
    return [fields sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *lhs, NSDictionary *rhs) {
        NSNumber *lhsOffset = lhs[@"offsetBytes"] ?: @(NSIntegerMax);
        NSNumber *rhsOffset = rhs[@"offsetBytes"] ?: @(NSIntegerMax);
        NSComparisonResult result = [lhsOffset compare:rhsOffset];
        if (result != NSOrderedSame) {
            return result;
        }
        return [lhs[@"sourceOrder"] compare:rhs[@"sourceOrder"]];
    }];
}

- (NSArray<NSDictionary *> *)allTypes {
    NSMutableArray<NSDictionary *> *types = [NSMutableArray array];
    for (NSDictionary *package in self.currentRecord[@"dump"][@"packages"] ?: @[]) {
        [types addObjectsFromArray:package[@"types"] ?: @[]];
    }
    return types;
}

- (NSDictionary *)parentTypeForType:(NSDictionary *)type {
    NSString *parentName = type[@"parentTypeName"];
    if (parentName.length == 0) {
        return nil;
    }

    for (NSDictionary *candidate in [self allTypes]) {
        if ([candidate[@"name"] isEqualToString:parentName]) {
            return candidate;
        }
    }
    return nil;
}

- (NSArray<NSDictionary *> *)childTypesForType:(NSDictionary *)type {
    NSString *name = type[@"name"] ?: @"";
    NSMutableArray<NSDictionary *> *children = [NSMutableArray array];
    for (NSDictionary *candidate in [self allTypes]) {
        if ([candidate[@"parentTypeName"] isEqualToString:name] && ![candidate[@"fullName"] isEqualToString:type[@"fullName"]]) {
            [children addObject:candidate];
        }
    }
    return [children sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *lhs, NSDictionary *rhs) {
        return [lhs[@"name"] compare:rhs[@"name"]];
    }];
}

- (NSArray<NSDictionary *> *)siblingTypesForType:(NSDictionary *)type {
    NSString *parentName = type[@"parentTypeName"];
    if (parentName.length == 0) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *siblings = [NSMutableArray array];
    for (NSDictionary *candidate in [self allTypes]) {
        if ([candidate[@"parentTypeName"] isEqualToString:parentName] && ![candidate[@"fullName"] isEqualToString:type[@"fullName"]]) {
            [siblings addObject:candidate];
        }
    }
    return [siblings sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *lhs, NSDictionary *rhs) {
        return [lhs[@"name"] compare:rhs[@"name"]];
    }];
}

- (NSArray<NSDictionary *> *)ancestorsForType:(NSDictionary *)type {
    NSMutableArray<NSDictionary *> *ancestors = [NSMutableArray array];
    NSMutableSet<NSString *> *visited = [NSMutableSet setWithObject:type[@"name"] ?: @""];
    NSDictionary *current = [self parentTypeForType:type];
    while (current && ![visited containsObject:current[@"name"] ?: @""]) {
        [ancestors insertObject:current atIndex:0];
        [visited addObject:current[@"name"] ?: @""];
        current = [self parentTypeForType:current];
    }
    return ancestors;
}

- (NSString *)hexStringForNumber:(NSNumber *)number {
    return [NSString stringWithFormat:@"0x%llX", number.unsignedLongLongValue];
}

- (void)presentSheet:(UIAlertController *)sheet sourceView:(UIView *)sourceView {
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.sourceView = sourceView ?: self.view;
        popover.sourceRect = sourceView ? sourceView.bounds : self.view.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
