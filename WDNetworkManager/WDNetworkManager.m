//
//  WDNetworkManager.m
//  WDNetworkManager
//
//  Created by wd on 2017/7/1.
//  Copyright © 2017年 wd. All rights reserved.
//

#import "WDNetworkManager.h"
#import "AFNetworking.h"
#import "NSString+MD5.h"

@interface WDNetworkManager ()

@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@property (nonatomic, strong) NSMutableArray *allSessionTaskArray;

@end

@implementation WDNetworkManager

+ (WDNetworkManager *)networkManager {
    static WDNetworkManager * manager = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        [self initNetworkManager];
    }
    return self;
}

- (void)initNetworkManager {
    _sessionManager = [AFHTTPSessionManager manager];
    // 设置超时时间
    _sessionManager.requestSerializer.timeoutInterval = 15.f;
    //此地方可以设置requestSerializer 一些共用header之类的。
    
    _sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
    _sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/html", @"text/json", @"text/plain", @"text/javascript", @"text/xml", @"image/*", nil];
}

//存放所有请求的数组
- (NSMutableArray *)allSessionTaskArray {
    if (!_allSessionTaskArray) {
        _allSessionTaskArray = [[NSMutableArray alloc] init];
    }
    return _allSessionTaskArray;
 
}

+ (void)startMonitoringNetwork {
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
}

+ (BOOL)isNetwork {
    return [AFNetworkReachabilityManager sharedManager].reachable;
}

+ (BOOL)isWWANNetwork {
    return [AFNetworkReachabilityManager sharedManager].reachableViaWWAN;
}

+ (BOOL)isWiFiNetwork {
    return [AFNetworkReachabilityManager sharedManager].reachableViaWiFi;
}

#pragma mark - 开始监听网络
+ (void)networkStatusWithBlock:(WDNetworkStatus)networkStatus {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            switch (status) {
                case AFNetworkReachabilityStatusUnknown:
                    networkStatus ? networkStatus(WDNetworkStatusType_Unknown) : nil;
                    break;
                case AFNetworkReachabilityStatusNotReachable:
                    networkStatus ? networkStatus(WDNetworkStatusType_NotReachable) : nil;
                    break;
                case AFNetworkReachabilityStatusReachableViaWWAN:
                    networkStatus ? networkStatus(WDNetworkStatusType_ReachableViaWWAN) : nil;
                    break;
                case AFNetworkReachabilityStatusReachableViaWiFi:
                    networkStatus ? networkStatus(WDNetworkStatusType_ReachableViaWiFi) : nil;
                    break;
            }
        }];
    });
}

+ (void)cancelAllRequest {
    // 锁操作
    @synchronized(self) {
        [[WDNetworkManager networkManager].allSessionTaskArray enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            [task cancel];
        }];
        [[WDNetworkManager networkManager].allSessionTaskArray removeAllObjects];
    }
}

+ (void)cancelRequestWithURL:(NSString *)URL {
    if (!URL) { return; }
    @synchronized (self) {
        [[WDNetworkManager networkManager].allSessionTaskArray enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task.currentRequest.URL.absoluteString hasPrefix:URL]) {
                [task cancel];
                [[WDNetworkManager networkManager].allSessionTaskArray removeObject:task];
                *stop = YES;
            }
        }];
    }
}

+ (__kindof NSURLSessionTask *)GET:(NSString *)URL
                        parameters:(id)parameters
                           success:(WDHttpRequestSuccess)success
                           failure:(WDHttpRequestSuccess)failure {
    return [self GET:URL parameters:parameters responseCache:nil success:success failure:failure];
}

+ (__kindof NSURLSessionTask *)GET:(NSString *)URL
                        parameters:(id)parameters
                     responseCache:(WDHttpRequestCache)responseCache
                           success:(WDHttpRequestSuccess)success
                           failure:(WDHttpRequestSuccess)failure {
    if (responseCache) {
        responseCache([self loadCacheWithURLString:URL]);
    }
    
    NSURLSessionTask *sessionTask = [[WDNetworkManager networkManager].sessionManager GET:URL parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [[WDNetworkManager networkManager].allSessionTaskArray removeObject:task];
        success ? success(responseObject) : nil;
        //对数据进行异步缓存
        if (responseCache) {
            [self saveCancheWithDict:responseObject withURLString:URL];
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        [[WDNetworkManager networkManager].allSessionTaskArray removeObject:task];
        failure ? failure(error) : nil;
        
    }];
    // 添加sessionTask到数组
    sessionTask ? [[WDNetworkManager networkManager].allSessionTaskArray addObject:sessionTask] : nil ;
    
    return sessionTask;
}

+ (__kindof NSURLSessionTask *)POST:(NSString *)URL
                         parameters:(id)parameters
                            success:(WDHttpRequestSuccess)success
                            failure:(WDHttpRequestFailed)failure {
    return [self POST:URL parameters:parameters responseCache:nil success:success failure:failure];
}

+ (__kindof NSURLSessionTask *)POST:(NSString *)URL
                         parameters:(id)parameters
                      responseCache:(WDHttpRequestCache)responseCache
                            success:(WDHttpRequestSuccess)success
                            failure:(WDHttpRequestFailed)failure {
    if (responseCache) {
        responseCache([self loadCacheWithURLString:URL]);
    }
    
    NSURLSessionTask *sessionTask = [[WDNetworkManager networkManager].sessionManager POST:URL parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [[WDNetworkManager networkManager].allSessionTaskArray removeObject:task];
        success ? success(responseObject) : nil;
        //对数据进行异步缓存
        if (responseCache) {
            [self saveCancheWithDict:responseObject withURLString:URL];
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        [[WDNetworkManager networkManager].allSessionTaskArray removeObject:task];
        failure ? failure(error) : nil;
        
    }];
    
    // 添加最新的sessionTask到数组
    sessionTask ? [[WDNetworkManager networkManager].allSessionTaskArray addObject:sessionTask] : nil ;
    return sessionTask;

}

+ (void)saveCancheWithDict:(NSDictionary *)cacheDict withURLString:(NSString *)URL {
    
    if (cacheDict) {
        [NSKeyedArchiver archiveRootObject:cacheDict toFile:[self getCachePathWithURLString:URL]];
    }
}

+ (NSDictionary *)loadCacheWithURLString:(NSString *)URL {
    NSDictionary *dict = nil;
    NSString *cachePath = [self getCachePathWithURLString:URL];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        dict = [NSKeyedUnarchiver unarchiveObjectWithFile:cachePath];
    }
    return dict;
}

+ (void)clearCache {
    NSString *cachePath = [NSString stringWithFormat:@"%@/apiCache", [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
    }
}

+ (NSString *)getCachePathWithURLString:(NSString *)URL {
    return [NSString stringWithFormat:@"%@/apiCache/%@.dat", [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject],[URL wd_md5]];
}

+ (__kindof NSURLSessionTask *)uploadFileWithURL:(NSString *)URL
                                      parameters:(id)parameters
                                            name:(NSString *)name
                                        filePath:(NSString *)filePath
                                        progress:(WDHttpProgress)progress
                                         success:(WDHttpRequestSuccess)success
                                         failure:(WDHttpRequestFailed)failure {
    NSURLSessionTask *sessionTask = [[WDNetworkManager networkManager].sessionManager POST:URL parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        NSError *error = nil;
        [formData appendPartWithFileURL:[NSURL URLWithString:filePath] name:name error:&error];
        (failure && error) ? failure(error) : nil;
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        //上传进度
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(uploadProgress) : nil;
        });
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [[WDNetworkManager networkManager].allSessionTaskArray removeObject:task];
        success ? success(responseObject) : nil;
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        [[WDNetworkManager networkManager].allSessionTaskArray  removeObject:task];
        failure ? failure(error) : nil;
    }];
    
    // 添加sessionTask到数组
    sessionTask ? [[WDNetworkManager networkManager].allSessionTaskArray  addObject:sessionTask] : nil ;
    
    return sessionTask;

}


+ (__kindof NSURLSessionTask *)uploadImagesWithURL:(NSString *)URL
                                        parameters:(id)parameters
                                              name:(NSString *)name
                                            images:(NSArray<UIImage *> *)images
                                         fileNames:(NSArray<NSString *> *)fileNames
                                        imageScale:(CGFloat)imageScale
                                         imageType:(NSString *)imageType
                                          progress:(WDHttpProgress)progress
                                           success:(WDHttpRequestSuccess)success
                                           failure:(WDHttpRequestFailed)failure {
    NSURLSessionTask *sessionTask = [[WDNetworkManager networkManager].sessionManager POST:URL parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        
        for (NSUInteger i = 0; i < images.count; i++) {
            // 图片经过等比压缩后得到的二进制文件
            NSData *imageData = UIImageJPEGRepresentation(images[i], imageScale ?: 1.f);
            // 默认图片的文件名, 若fileNames为nil就使用
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyyMMddHHmmss";
            NSString *str = [formatter stringFromDate:[NSDate date]];
            NSString *imageFileName = [NSString stringWithFormat:@"%@%ld.%@",str,i,imageType?:@"jpg"];
            
            [formData appendPartWithFileData:imageData
                                        name:name
                                    fileName:fileNames ? [NSString stringWithFormat:@"%@.%@",fileNames[i],imageType?:@"jpg"] : imageFileName
                                    mimeType:[NSString stringWithFormat:@"image/%@",imageType ?: @"jpg"]];
        }
        
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        //上传进度
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(uploadProgress) : nil;
        });
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [[WDNetworkManager networkManager].allSessionTaskArray removeObject:task];
        success ? success(responseObject) : nil;
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        [[WDNetworkManager networkManager].allSessionTaskArray removeObject:task];
        failure ? failure(error) : nil;
    }];
    
    // 添加sessionTask到数组
    sessionTask ? [[WDNetworkManager networkManager].allSessionTaskArray addObject:sessionTask] : nil ;
    
    return sessionTask;
}

+ (__kindof NSURLSessionTask *)downloadWithURL:(NSString *)URL
                                       fileDir:(NSString *)fileDir
                                      progress:(WDHttpProgress)progress
                                       success:(void(^)(NSString *filePath))success
                                       failure:(WDHttpRequestFailed)failure {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URL]];
    __block NSURLSessionDownloadTask *downloadTask = [[WDNetworkManager networkManager].sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        //下载进度
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(downloadProgress) : nil;
        });
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        //拼接缓存目录
        NSString *downloadDir = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:fileDir ? fileDir : @"Download"];
        //打开文件管理器
        NSFileManager *fileManager = [NSFileManager defaultManager];
        //创建Download目录
        [fileManager createDirectoryAtPath:downloadDir withIntermediateDirectories:YES attributes:nil error:nil];
        //拼接文件路径
        NSString *filePath = [downloadDir stringByAppendingPathComponent:response.suggestedFilename];
        //返回文件位置的URL路径
        return [NSURL fileURLWithPath:filePath];
        
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        
        [[WDNetworkManager networkManager].allSessionTaskArray removeObject:downloadTask];
        if(failure && error) {failure(error) ; return ;};
        success ? success(filePath.absoluteString /** NSURL->NSString*/) : nil;
        
    }];
    //开始下载
    [downloadTask resume];
    // 添加sessionTask到数组
    downloadTask ? [[WDNetworkManager networkManager].allSessionTaskArray addObject:downloadTask] : nil ;
    
    return downloadTask;
}


@end
