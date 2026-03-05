import Foundation

struct WallpaperCategory: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let order_num: String?
    let tag: String?
    let create_time: String?
}

struct WallpaperImageDTO: Codable, Hashable {
    let id: String
    let class_id: String?
    let resolution: String?
    let url_mobile: String?
    let url: String?
    let url_thumb: String?
    let url_mid: String?
    let download_times: String?
    let imgcut: String?
    let tag: String?
    let create_time: String?
    let update_time: String?
    let ad_id: String?
    let ad_img: String?
    let ad_pos: String?
    let ad_url: String?
    let ext_1: String?
    let ext_2: String?
    let utag: String?
    let tempdata: String?
    let img_1600_900: String?
    let img_1440_900: String?
    let img_1366_768: String?
    let img_1280_800: String?
    let img_1280_1024: String?
    let img_1024_768: String?
    let url_mid_w: String?
    let url_mid_h: String?
    let url_thumb_w: String?
    let url_thumb_h: String?
}

struct WallpaperAPIListWrapper<T: Codable>: Codable {
    let data: [T]?
    let list: [T]?
    let result: [T]?
}
