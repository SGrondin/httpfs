using System;
using System.Configuration;

using Flurl;

using httpfsc.Business.FileSystem.Http;

namespace Httpfs.Client
{
    /// <summary>
    /// Currently loaded client exe config.
    /// </summary>
    public class ClientConfig : IHttpFileSystemProxyConfig
    {
        #region Properties

        /// <summary>
        /// Gets the path to the local folder configured as root for the client.
        /// </summary>
        public Url LocalRoot
        {
            get { return ConfigurationManager.AppSettings.Get("LocalRootPath"); }
        }

        /// <summary>
        /// Gets the server root path.
        /// </summary>
        public Url ServerRootPath
        {
            get { return ConfigurationManager.AppSettings.Get("ServerRootPath"); }
        }

        #endregion
    }
}