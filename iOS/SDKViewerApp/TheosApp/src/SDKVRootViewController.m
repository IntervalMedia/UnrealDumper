#import "SDKVRootViewController.h"
#import "SDKVProjectStore.h"
#import "SDKVPointerGenerator.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface SDKVRootViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) SDKVProjectStore *store;
@property (nonatomic, copy) NSString *currentProject;
@property (nonatomic, strong) NSDictionary *currentRecord;

@property (nonatomic, strong) UILabel *statusLabel;
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
    UIBarButtonItem *browseItem = [[UIBarButtonItem alloc] initWithTitle:@"Browse" style:UIBarButtonItemStylePlain target:self action:@selector(browseTapped)];
    self.navigationItem.leftBarButtonItems = @[createItem, loadItem];
    self.navigationItem.rightBarButtonItems = @[importItem, browseItem];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(16, 16, self.view.bounds.size.width - 32, 1000)];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [scroll addSubview:container];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, container.bounds.size.width, 44)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.text = @"Create or load a local project to start.";
    [container addSubview:self.statusLabel];

    UILabel *sourceTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 52, container.bounds.size.width, 20)];
    sourceTitle.text = @"Type Source";
    sourceTitle.font = [UIFont boldSystemFontOfSize:16];
    [container addSubview:sourceTitle];

    self.sourceView = [[UITextView alloc] initWithFrame:CGRectMake(0, 76, container.bounds.size.width, 320)];
    self.sourceView.editable = NO;
    self.sourceView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.sourceView.text = @"Import an SDK ZIP and choose Browse to navigate package/type source.";
    [container addSubview:self.sourceView];

    UILabel *pointerTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 408, container.bounds.size.width, 20)];
    pointerTitle.text = @"Pointer Chain Generator";
    pointerTitle.font = [UIFont boldSystemFontOfSize:16];
    [container addSubview:pointerTitle];

    self.baseField = [self makeField:@"Base expression (e.g. baseAddress)" y:436 width:container.bounds.size.width];
    self.baseField.text = @"baseAddress";
    [container addSubview:self.baseField];

    self.offsetsField = [self makeField:@"Offsets (comma separated: 0x30, 0x18, 0x8)" y:476 width:container.bounds.size.width];
    self.offsetsField.text = @"0x30, 0x18, 0x8";
    [container addSubview:self.offsetsField];

    self.typeField = [self makeField:@"Result type" y:516 width:container.bounds.size.width];
    self.typeField.text = @"uintptr_t";
    [container addSubview:self.typeField];

    self.nameField = [self makeField:@"Result variable name" y:556 width:container.bounds.size.width];
    self.nameField.text = @"resultPtr";
    [container addSubview:self.nameField];

    UIButton *generateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    generateBtn.frame = CGRectMake(0, 596, 160, 36);
    [generateBtn setTitle:@"Generate C++" forState:UIControlStateNormal];
    [generateBtn addTarget:self action:@selector(generatePointerTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:generateBtn];

    self.pointerOutputView = [[UITextView alloc] initWithFrame:CGRectMake(0, 640, container.bounds.size.width, 260)];
    self.pointerOutputView.editable = NO;
    self.pointerOutputView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    [container addSubview:self.pointerOutputView];

    container.frame = CGRectMake(16, 16, self.view.bounds.size.width - 32, 920);
    scroll.contentSize = CGSizeMake(self.view.bounds.size.width, 960);
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

- (void)browseTapped {
    NSArray *packages = self.currentRecord[@"dump"][@"packages"];
    if (packages.count == 0) {
        [self showError:@"No parsed packages found. Import a ZIP first."];
        return;
    }

    UIAlertController *pkgSheet = [UIAlertController alertControllerWithTitle:@"Packages" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *pkg in packages) {
        NSString *pkgName = pkg[@"name"] ?: @"Unknown";
        [pkgSheet addAction:[UIAlertAction actionWithTitle:pkgName style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self presentTypeBrowserForPackage:pkg];
        }]];
    }
    [pkgSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:pkgSheet animated:YES completion:nil];
}

- (void)presentTypeBrowserForPackage:(NSDictionary *)package {
    NSArray *types = package[@"types"] ?: @[];
    if (types.count == 0) {
        [self showError:@"Package has no parsed types"];
        return;
    }

    UIAlertController *typeSheet = [UIAlertController alertControllerWithTitle:package[@"name"] message:@"Select a type" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *type in types) {
        NSString *title = [NSString stringWithFormat:@"[%@] %@", type[@"kind"] ?: @"type", type[@"name"] ?: @"Unknown"];
        [typeSheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.sourceView.text = type[@"body"] ?: @"";
        }]];
    }
    [typeSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:typeSheet animated:YES completion:nil];
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
    [self refreshStatus];
}

- (void)refreshStatus {
    NSDictionary *metadata = self.currentRecord[@"metadata"];
    NSArray *packages = self.currentRecord[@"dump"][@"packages"] ?: @[];
    self.statusLabel.text = [NSString stringWithFormat:@"Project: %@\nPackages: %lu", metadata[@"name"] ?: @"-", (unsigned long)packages.count];
}

- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
